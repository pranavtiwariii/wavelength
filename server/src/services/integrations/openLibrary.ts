import { TtlCache } from '../../lib/cache.js';
import type { TasteProvider, TasteSearchResult } from './types.js';

const cache = new TtlCache<TasteSearchResult[]>(1000 * 60 * 60 * 6);

/**
 * Book search via Open Library - no API key required, which is why it's the
 * default over Google Books. Goodreads CSV import remains the power-user path
 * (spec 3.2); there's no modern public Goodreads API to OAuth against.
 */
export const openLibraryProvider: TasteProvider = {
  domain: 'book',
  name: 'Open Library',
  available: true,

  async search(query, signal) {
    const cacheKey = query.toLowerCase();
    const cached = cache.get(cacheKey);
    if (cached) return cached;

    const url = new URL('https://openlibrary.org/search.json');
    url.searchParams.set('q', query);
    url.searchParams.set('limit', '10');
    url.searchParams.set('fields', 'key,title,author_name,first_publish_year,cover_i');

    const res = await fetch(url, signal ? { signal } : {});
    if (!res.ok) throw new Error(`Open Library responded ${res.status}`);

    const body = (await res.json()) as {
      docs?: Array<{
        key: string;
        title: string;
        author_name?: string[];
        first_publish_year?: number;
        cover_i?: number;
      }>;
    };

    const results: TasteSearchResult[] = (body.docs ?? []).map((doc) => {
      const author = doc.author_name?.[0];
      const year = doc.first_publish_year;
      const subtitle = [author, year].filter(Boolean).join(' · ');
      return {
        key: `openlibrary:work:${doc.key.replace('/works/', '')}`,
        label: doc.title,
        ...(subtitle ? { subtitle } : {}),
        ...(doc.cover_i
          ? { imageUrl: `https://covers.openlibrary.org/b/id/${doc.cover_i}-M.jpg` }
          : {}),
      };
    });

    cache.set(cacheKey, results);
    return results;
  },
};
