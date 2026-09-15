import { TtlCache } from '../../lib/cache.js';
import type { TasteProvider, TasteSearchResult } from './types.js';

const cache = new TtlCache<TasteSearchResult[]>(1000 * 60 * 60 * 6);

/**
 * Artist search via MusicBrainz - no API key, so taste import works before
 * Spotify OAuth lands. Spotify will become the primary music source (it brings
 * listening history and audio features); this stays as the manual "search and
 * add" path and the fallback for users who don't connect an account.
 *
 * MusicBrainz requires a descriptive User-Agent and asks for <= 1 req/sec.
 */
const USER_AGENT = 'Wavelength/0.1 (https://github.com/wavelength-app)';

export const musicBrainzProvider: TasteProvider = {
  domain: 'music',
  name: 'MusicBrainz',
  available: true,

  async search(query, signal) {
    const cacheKey = query.toLowerCase();
    const cached = cache.get(cacheKey);
    if (cached) return cached;

    const url = new URL('https://musicbrainz.org/ws/2/artist');
    url.searchParams.set('query', query);
    url.searchParams.set('fmt', 'json');
    url.searchParams.set('limit', '10');

    // MusicBrainz asks for <= 1 request/second and answers 503 when exceeded.
    // One short backoff turns a burst into a small delay instead of an error.
    let res = await fetch(url, {
      headers: { 'User-Agent': USER_AGENT },
      ...(signal ? { signal } : {}),
    });
    if (res.status === 503) {
      await new Promise((resolve) => setTimeout(resolve, 1200));
      res = await fetch(url, {
        headers: { 'User-Agent': USER_AGENT },
        ...(signal ? { signal } : {}),
      });
    }
    if (!res.ok) throw new Error(`MusicBrainz responded ${res.status}`);

    const body = (await res.json()) as {
      artists?: Array<{
        id: string;
        name: string;
        disambiguation?: string;
        country?: string;
        type?: string;
        tags?: Array<{ name: string; count: number }>;
        'life-span'?: { begin?: string };
      }>;
    };

    const results: TasteSearchResult[] = (body.artists ?? []).map((artist) => {
      const tags = (artist.tags ?? [])
        .sort((a, b) => b.count - a.count)
        .map((t) => t.name.toLowerCase())
        .slice(0, 6);
      const subtitle =
        artist.disambiguation || tags[0] || [artist.type, artist.country].filter(Boolean).join(' · ');
      const begin = artist['life-span']?.begin;
      const year = begin ? Number(begin.slice(0, 4)) : undefined;

      return {
        key: `musicbrainz:artist:${artist.id}`,
        label: artist.name,
        ...(subtitle ? { subtitle } : {}),
        meta: {
          ...(tags.length ? { genres: tags } : {}),
          ...(Number.isFinite(year) ? { year: year as number } : {}),
          creator: artist.name,
        },
      };
    });

    cache.set(cacheKey, results);
    return results;
  },
};
