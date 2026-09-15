import { TtlCache } from '../../lib/cache.js';
import type { TasteProvider, TasteSearchResult } from './types.js';

const cache = new TtlCache<TasteSearchResult[]>(1000 * 60 * 60 * 6);

/**
 * Artist search via the iTunes Search API. Keyless, and — unlike its movie
 * endpoints — the music entities still work. Used as the fallback when
 * MusicBrainz is unavailable, which it frequently is.
 *
 * Note the keys are namespaced per provider, so an artist added from iTunes and
 * the same artist added from MusicBrainz do NOT collide. MusicBrainz stays the
 * primary so keys stay consistent whenever it is reachable.
 */
export const itunesMusicProvider: TasteProvider = {
  domain: 'music',
  name: 'iTunes',
  available: true,

  async search(query, signal) {
    const cacheKey = query.toLowerCase();
    const cached = cache.get(cacheKey);
    if (cached) return cached;

    const url = new URL('https://itunes.apple.com/search');
    url.searchParams.set('term', query);
    url.searchParams.set('entity', 'musicArtist');
    url.searchParams.set('limit', '12');

    const res = await fetch(url, signal ? { signal } : {});
    if (!res.ok) throw new Error(`iTunes responded ${res.status}`);

    const body = (await res.json()) as {
      results?: Array<{
        artistId: number;
        artistName: string;
        primaryGenreName?: string;
      }>;
    };

    const results: TasteSearchResult[] = (body.results ?? []).map((a) => ({
      key: `itunes:artist:${a.artistId}`,
      label: a.artistName,
      ...(a.primaryGenreName ? { subtitle: a.primaryGenreName.toLowerCase() } : {}),
      meta: {
        ...(a.primaryGenreName ? { genres: [a.primaryGenreName.toLowerCase()] } : {}),
        creator: a.artistName,
      },
    }));

    cache.set(cacheKey, results);
    return results;
  },
};
