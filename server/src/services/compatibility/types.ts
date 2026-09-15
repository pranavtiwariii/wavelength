export type Domain = 'music' | 'movie' | 'book';

/** A sparse, non-negative distribution (genre -> weight). Need not be normalised. */
export type Vector = Record<string, number>;

/**
 * One concrete thing a user loves. `key` is the stable cross-user identity
 * (e.g. "spotify:artist:4Z8W...", "tmdb:movie:843"), `label` is for display.
 */
export interface TasteItem {
  key: string;
  label: string;
}

export interface DomainProfile {
  /** Taste *shape*: genre distribution, audio-feature centroid, etc. */
  vector: Vector;
  /** Literal favourites, for exact-overlap scoring. */
  items: TasteItem[];
  /** Era or mood distribution, scored separately in the 0.20 term. */
  styleVector: Vector;
  /** False when the user has not connected/filled this domain at all. */
  present: boolean;
}

export interface UserTasteProfile {
  userId: string;
  music: DomainProfile;
  movie: DomainProfile;
  book: DomainProfile;
  /** User's own ranking of what matters (spec 5.3). 1 = normal, higher = more. */
  domainPriority: Record<Domain, number>;
}

/** How many users on the platform have each item as a favourite (spec 5.2). */
export interface PopularityIndex {
  totalUsers: number;
  counts: Record<string, number>;
}

export interface SharedHighlight {
  domain: Domain;
  key: string;
  label: string;
  /** Rarity weight that earned it a place - higher means more distinctive. */
  weight: number;
}

export interface DivergenceHighlight {
  domain: Domain;
  key: string;
  label: string;
  /** Which user holds this item; the other one does not. */
  heldBy: string;
  weight: number;
}

export interface DomainScore {
  score: number;          // 0-100
  cosine: number;         // 0-1
  weightedJaccard: number; // 0-1
  styleAlignment: number;  // 0-1
  /** False when either side lacks the domain; excluded from the overall blend. */
  comparable: boolean;
}

export interface CompatibilityResult {
  overallScore: number;
  music: DomainScore;
  movie: DomainScore;
  book: DomainScore;
  /** Effective per-domain weights actually used, after completeness/priority. */
  weights: Record<Domain, number>;
  sharedHighlights: SharedHighlight[];
  divergenceHighlights: DivergenceHighlight[];
}
