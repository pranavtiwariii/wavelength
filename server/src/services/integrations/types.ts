export type Domain = 'music' | 'movie' | 'book';

/** One searchable thing a user can add to their taste profile. */
export interface TasteSearchResult {
  /** Stable cross-user identity, namespaced by provider. */
  key: string;
  label: string;
  /** Artist, author, year - whatever disambiguates two similar titles. */
  subtitle?: string;
  imageUrl?: string;
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
