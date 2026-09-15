import { config } from '../../config.js';
import { TtlCache } from '../../lib/cache.js';
import type { TasteProvider, TasteSearchResult } from './types.js';

const cache = new TtlCache<TasteSearchResult[]>(1000 * 60 * 60 * 6);

/**
 * Film search via TMDB. Unlike music and books, there is no good keyless
 * alternative here, so this provider reports itself unavailable until
 * TMDB_API_KEY is set and the UI shows that state instead of failing on tap.
 *
 * Accepts either a v3 API key or a v4 read access token.
 */
export const tmdbProvider: TasteProvider = {
  domain: 'movie',
  name: 'TMDB',
  get available() {
    return Boolean(config.tmdbApiKey);
  },
  unavailableReason: 'Film search needs a TMDB API key on the server.',

  async search(query, signal) {
    const apiKey = config.tmdbApiKey;
    if (!apiKey) throw new Error('TMDB_API_KEY is not configured');

    const cacheKey = query.toLowerCase();
    const cached = cache.get(cacheKey);
    if (cached) return cached;

    const url = new URL('https://api.themoviedb.org/3/search/movie');
    url.searchParams.set('query', query);
    url.searchParams.set('include_adult', 'false');

    // v4 tokens are JWTs and go in the Authorization header; v3 keys are a
    // query parameter.
    const headers: Record<string, string> = { accept: 'application/json' };
    if (apiKey.startsWith('ey')) {
      headers.Authorization = `Bearer ${apiKey}`;
    } else {
      url.searchParams.set('api_key', apiKey);
    }

    const res = await fetch(url, { headers, ...(signal ? { signal } : {}) });
    if (!res.ok) throw new Error(`TMDB responded ${res.status}`);

    const body = (await res.json()) as {
      results?: Array<{
        id: number;
        title: string;
        release_date?: string;
        poster_path?: string | null;
      }>;
    };

    const results: TasteSearchResult[] = (body.results ?? []).slice(0, 10).map((film) => {
      const year = film.release_date?.slice(0, 4);
      return {
        key: `tmdb:movie:${film.id}`,
        label: film.title,
        ...(year ? { subtitle: year } : {}),
        ...(film.poster_path
          ? { imageUrl: `https://image.tmdb.org/t/p/w185${film.poster_path}` }
          : {}),
      };
    });

    cache.set(cacheKey, results);
    return results;
  },
};
