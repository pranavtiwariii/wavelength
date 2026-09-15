import { itunesMusicProvider } from './itunesMusic.js';
import { musicBrainzProvider } from './musicbrainz.js';
import { openLibraryProvider } from './openLibrary.js';
import { tmdbProvider } from './tmdb.js';
import { wikidataFilmProvider } from './wikidata.js';
import type { Domain, TasteProvider } from './types.js';

/**
 * Tries each provider in order and uses the first that answers. One upstream
 * outage (MusicBrainz 503s are routine) shouldn't take a whole taste domain
 * down — the user just needs *a* result for the thing they typed.
 */
function withFallback(domain: Domain, chain: TasteProvider[]): TasteProvider {
  return {
    domain,
    get name() {
      return (chain.find((p) => p.available) ?? chain[0]!).name;
    },
    get available() {
      return chain.some((p) => p.available);
    },
    get unavailableReason() {
      return chain[0]?.unavailableReason;
    },
    async search(query, signal) {
      let lastError: unknown;
      for (const provider of chain) {
        if (!provider.available) continue;
        try {
          const results = await provider.search(query, signal);
          if (results.length > 0) return results;
        } catch (err) {
          lastError = err;
        }
      }
      // Every provider failed outright (as opposed to returning nothing).
      if (lastError) throw lastError;
      return [];
    },
  };
}

export const providers: Record<Domain, TasteProvider> = {
  // MusicBrainz first: richer tags, and stable ids shared across users.
  music: withFallback('music', [musicBrainzProvider, itunesMusicProvider]),
  // TMDB when a key exists, otherwise keyless Wikidata.
  movie: withFallback('movie', [tmdbProvider, wikidataFilmProvider]),
  book: openLibraryProvider,
};

export * from './types.js';
