export type Domain = 'music' | 'movie' | 'book';

/** One searchable thing a user can add to their taste profile. */
export interface TasteSearchResult {
  /** Stable cross-user identity, namespaced by provider. */
  key: string;
  label: string;
  /** Artist, author, year - whatever disambiguates two similar titles. */
  subtitle?: string;
  imageUrl?: string;
  /**
   * Structured signal for the compatibility vectors. Captured at add time so
   * scoring never has to call a third party (NFR 9).
   */
  meta?: TasteItemMeta;
}

export interface TasteItemMeta {
  /** Genres/tags, lowercased. Feeds the genre distribution. */
  genres?: string[];
  /** Release/publication year. Feeds the era distribution. */
  year?: number;
  /** Director, author, or the artist themselves - the authorial signal. */
  creator?: string;
}

export interface TasteProvider {
  readonly domain: Domain;
  readonly name: string;
  /** False when the provider needs an API key that isn't configured. */
  readonly available: boolean;
  /** Why it's unavailable, shown to the user. */
  readonly unavailableReason?: string;
  search(query: string, signal?: AbortSignal): Promise<TasteSearchResult[]>;
}
