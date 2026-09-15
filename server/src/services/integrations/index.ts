import { musicBrainzProvider } from './musicbrainz.js';
import { openLibraryProvider } from './openLibrary.js';
import { tmdbProvider } from './tmdb.js';
import type { Domain, TasteProvider } from './types.js';

export const providers: Record<Domain, TasteProvider> = {
  music: musicBrainzProvider,
  movie: tmdbProvider,
  book: openLibraryProvider,
};

export * from './types.js';
