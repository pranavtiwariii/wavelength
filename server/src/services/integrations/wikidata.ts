import { TtlCache } from '../../lib/cache.js';
import type { TasteProvider, TasteSearchResult } from './types.js';

const cache = new TtlCache<TasteSearchResult[]>(1000 * 60 * 60 * 12);

const ENDPOINT = 'https://query.wikidata.org/sparql';
const USER_AGENT = 'Wavelength/0.1 (https://github.com/wavelength-app)';

/**
 * Film search via Wikidata's SPARQL endpoint - keyless, and it carries the
 * director, which matters here: the spec's whole premise is that sharing a
 * favourite director is a stronger signal than sharing a genre.
 *
 * TMDB takes over automatically when TMDB_API_KEY is set; this keeps the Movies
 * domain fully usable without one. (The iTunes Search API is not an option -
 * Apple has disabled its movie/tv media filters.)
 */
function buildQuery(term: string): string {
  // Escape for a SPARQL string literal.
  const safe = term.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  return `SELECT ?item ?itemLabel ?year ?directorLabel ?genreLabel ?image ?sitelinks WHERE {
  SERVICE wikibase:mwapi {
    bd:serviceParam wikibase:api "EntitySearch" .
    bd:serviceParam wikibase:endpoint "www.wikidata.org" .
    bd:serviceParam mwapi:search "${safe}" .
    bd:serviceParam mwapi:language "en" .
    ?item wikibase:apiOutputItem mwapi:item .
  }
  ?item wdt:P31/wdt:P279* wd:Q11424 .
  # Sitelink count = how many Wikipedia editions cover this film. The best
  # available notability proxy, and what decides ties between same-titled films.
  ?item wikibase:sitelinks ?sitelinks .
  OPTIONAL { ?item wdt:P577 ?date . BIND(YEAR(?date) AS ?year) }
  OPTIONAL { ?item wdt:P57 ?director }
  OPTIONAL { ?item wdt:P136 ?genre }
  OPTIONAL { ?item wdt:P18 ?image }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en" }
} LIMIT 40`;
}

interface SparqlBinding {
  item?: { value: string };
  itemLabel?: { value: string };
  sitelinks?: { value: string };
  year?: { value: string };
  directorLabel?: { value: string };
  genreLabel?: { value: string };
  image?: { value: string };
}

export const wikidataFilmProvider: TasteProvider = {
  domain: 'movie',
  name: 'Wikidata',
  available: true,

  async search(query, signal) {
    const cacheKey = query.toLowerCase();
    const cached = cache.get(cacheKey);
    if (cached) return cached;

    const url = new URL(ENDPOINT);
    url.searchParams.set('query', buildQuery(query));

    const res = await fetch(url, {
      headers: { Accept: 'application/sparql-results+json', 'User-Agent': USER_AGENT },
      ...(signal ? { signal } : {}),
    });
    if (!res.ok) throw new Error(`Wikidata responded ${res.status}`);

    const body = (await res.json()) as { results?: { bindings?: SparqlBinding[] } };

    // Wikidata yields one row per director/image combination, so collapse by
    // entity id and merge the directors back together.
    const byId = new Map<
      string,
      {
        label: string;
        year?: string;
        directors: Set<string>;
        genres: Set<string>;
        image?: string;
        rank: number;
        sitelinks: number;
      }
    >();

    for (const row of body.results?.bindings ?? []) {
      const uri = row.item?.value;
      const label = row.itemLabel?.value;
      if (!uri || !label) continue;
      // Unlabelled items come back as the bare Q-id; not useful to a human.
      if (/^Q\d+$/.test(label)) continue;

      const id = uri.split('/').pop()!;
      // mwapi returns rows in relevance order; remember first-seen position so
      // we can keep that ordering after collapsing duplicate rows.
      const existing =
        byId.get(id) ??
        {
          label,
          directors: new Set<string>(),
          genres: new Set<string>(),
          rank: byId.size,
          sitelinks: 0,
        };
      existing.sitelinks = Math.max(existing.sitelinks, Number(row.sitelinks?.value ?? 0));
      if (row.year?.value) existing.year ??= row.year.value;
      if (row.directorLabel?.value && !/^Q\d+$/.test(row.directorLabel.value)) {
        existing.directors.add(row.directorLabel.value);
      }
      if (row.genreLabel?.value && !/^Q\d+$/.test(row.genreLabel.value)) {
        existing.genres.add(row.genreLabel.value.toLowerCase());
      }
      if (row.image?.value) existing.image ??= row.image.value;
      byId.set(id, existing);
    }

    const normalisedQuery = query.trim().toLowerCase();

    const results: TasteSearchResult[] = [...byId.entries()]
      .map(([id, film]) => {
        const directors = [...film.directors].slice(0, 2).join(', ');
        const subtitle = [film.year, directors].filter(Boolean).join(' · ');
        return {
          entry: {
            key: `wikidata:film:${id}`,
            label: film.label,
            ...(subtitle ? { subtitle } : {}),
            ...(film.image ? { imageUrl: `${film.image}?width=300` } : {}),
            meta: {
              ...(film.genres.size ? { genres: [...film.genres].slice(0, 6) } : {}),
              ...(film.year ? { year: Number(film.year) } : {}),
              ...(film.directors.size ? { creator: [...film.directors][0] } : {}),
            },
          },
          // Rank: exact title match first, then notability (sitelinks), which
          // is what separates Parasite (2019) from four other films called
          // Parasite. Search relevance only breaks remaining ties.
          score:
            (film.label.toLowerCase() === normalisedQuery ? 10000 : 0) +
            film.sitelinks * 10 +
            (film.directors.size > 0 ? 5 : 0) -
            film.rank,
        };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, 12)
      .map((r) => r.entry);

    cache.set(cacheKey, results);
    return results;
  },
};
