import type { PopularityIndex, TasteItem, Vector } from './types.js';

/**
 * Cosine similarity over sparse vectors, in [0, 1] for non-negative input.
 * Two empty/orthogonal vectors score 0 rather than NaN.
 */
export function cosineSimilarity(a: Vector, b: Vector): number {
  let dot = 0;
  let magA = 0;
  let magB = 0;

  for (const value of Object.values(a)) magA += value * value;
  for (const value of Object.values(b)) magB += value * value;

  // Iterate the smaller side; keys absent from the other contribute nothing.
  const [small, large] = Object.keys(a).length <= Object.keys(b).length ? [a, b] : [b, a];
  for (const [key, value] of Object.entries(small)) {
    const other = large[key];
    if (other !== undefined) dot += value * other;
  }

  if (magA === 0 || magB === 0) return 0;
  return clamp01(dot / (Math.sqrt(magA) * Math.sqrt(magB)));
}

/**
 * Inverse-popularity weight (spec 5.2): an item almost nobody favourites is a
 * far stronger compatibility signal than a chart-topper. Shaped like IDF, and
 * always >= a small floor so a shared mainstream item still counts for
 * something. An unseen item is treated as maximally rare.
 */
export function rarityWeight(key: string, popularity: PopularityIndex): number {
  const total = Math.max(popularity.totalUsers, 1);
  const count = popularity.counts[key] ?? 0;
  return Math.log(1 + total / (1 + count));
}

/**
 * Jaccard over exact favourites, with each item weighted by rarity, so the
 * overlap of two obscure films outweighs the overlap of two blockbusters.
 */
export function weightedJaccard(
  a: TasteItem[],
  b: TasteItem[],
  popularity: PopularityIndex,
): number {
  const keysA = new Set(a.map((i) => i.key));
  const keysB = new Set(b.map((i) => i.key));
  if (keysA.size === 0 || keysB.size === 0) return 0;

  let intersection = 0;
  let union = 0;
  for (const key of new Set([...keysA, ...keysB])) {
    const w = rarityWeight(key, popularity);
    union += w;
    if (keysA.has(key) && keysB.has(key)) intersection += w;
  }

  return union === 0 ? 0 : clamp01(intersection / union);
}

/**
 * Overlap of two distributions (sum of per-key minima after normalising).
 * Used for era/mood alignment, where "both 60% melancholic" should read as
 * aligned even though cosine would also reward shared *shape* elsewhere.
 */
export function distributionOverlap(a: Vector, b: Vector): number {
  const na = normalise(a);
  const nb = normalise(b);
  if (Object.keys(na).length === 0 || Object.keys(nb).length === 0) return 0;

  let overlap = 0;
  for (const [key, value] of Object.entries(na)) {
    const other = nb[key];
    if (other !== undefined) overlap += Math.min(value, other);
  }
  return clamp01(overlap);
}

/** Scales a vector to sum to 1. An all-zero vector stays empty. */
export function normalise(v: Vector): Vector {
  const total = Object.values(v).reduce((sum, x) => sum + x, 0);
  if (total <= 0) return {};
  const out: Vector = {};
  for (const [key, value] of Object.entries(v)) out[key] = value / total;
  return out;
}

export function clamp01(n: number): number {
  if (Number.isNaN(n)) return 0;
  return Math.min(1, Math.max(0, n));
}
