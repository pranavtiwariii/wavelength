import {
  clamp01,
  cosineSimilarity,
  distributionOverlap,
  rarityWeight,
  weightedJaccard,
} from './math.js';
import type {
  CompatibilityResult,
  DivergenceHighlight,
  Domain,
  DomainProfile,
  DomainScore,
  PopularityIndex,
  SharedHighlight,
  UserTasteProfile,
} from './types.js';

const DOMAINS: readonly Domain[] = ['music', 'movie', 'book'] as const;

/** Spec 5.2 term weights. Exported so tests and tuning can reference them. */
export const TERM_WEIGHTS = {
  cosine: 0.45,
  jaccard: 0.35,
  style: 0.2,
} as const;

const NOT_COMPARABLE: DomainScore = {
  score: 0,
  cosine: 0,
  weightedJaccard: 0,
  styleAlignment: 0,
  comparable: false,
};

export function scoreDomain(
  a: DomainProfile,
  b: DomainProfile,
  popularity: PopularityIndex,
): DomainScore {
  // A domain only counts when BOTH sides have data - otherwise an unconnected
  // domain would silently drag the pair's score toward zero (spec 5.3).
  if (!a.present || !b.present) return NOT_COMPARABLE;

  const cosine = cosineSimilarity(a.vector, b.vector);
  const jaccard = weightedJaccard(a.items, b.items, popularity);
  const style = distributionOverlap(a.styleVector, b.styleVector);

  const raw =
    TERM_WEIGHTS.cosine * cosine + TERM_WEIGHTS.jaccard * jaccard + TERM_WEIGHTS.style * style;

  return {
    score: Math.round(clamp01(raw) * 100),
    cosine,
    weightedJaccard: jaccard,
    styleAlignment: style,
    comparable: true,
  };
}

/**
 * Spec 5.3: weights are not fixed at a third each. A domain contributes only
 * if both users have it, scaled by how much data is actually there and by the
 * user's own stated priority. Weights are renormalised to sum to 1.
 */
export function effectiveWeights(
  a: UserTasteProfile,
  b: UserTasteProfile,
  scores: Record<Domain, DomainScore>,
): Record<Domain, number> {
  const raw: Record<Domain, number> = { music: 0, movie: 0, book: 0 };

  for (const domain of DOMAINS) {
    if (!scores[domain].comparable) continue;
    // Completeness proxy: the thinner side caps how much this domain can say.
    const depth = Math.min(a[domain].items.length, b[domain].items.length);
    const completeness = clamp01(depth / 10);
    const priority = (a.domainPriority[domain] + b.domainPriority[domain]) / 2;
    raw[domain] = Math.max(completeness, 0.25) * priority;
  }

  const total = DOMAINS.reduce((sum, d) => sum + raw[d], 0);
  if (total === 0) return { music: 0, movie: 0, book: 0 };

  return {
    music: raw.music / total,
    movie: raw.movie / total,
    book: raw.book / total,
  };
}

/**
 * Spec 5.4: the concrete items that drove the score, so the UI never has to
 * reverse-engineer "why" from a number. Ranked by rarity - the most
 * distinctive shared taste first.
 */
export function collectSharedHighlights(
  a: UserTasteProfile,
  b: UserTasteProfile,
  popularity: PopularityIndex,
  limit = 8,
): SharedHighlight[] {
  const out: SharedHighlight[] = [];

  for (const domain of DOMAINS) {
    if (!a[domain].present || !b[domain].present) continue;
    const bKeys = new Map(b[domain].items.map((i) => [i.key, i]));
    for (const item of a[domain].items) {
      if (!bKeys.has(item.key)) continue;
      out.push({ domain, key: item.key, label: item.label, weight: rarityWeight(item.key, popularity) });
    }
  }

  return out.sort((x, y) => y.weight - x.weight).slice(0, limit);
}

/**
 * Spec 2/4.6: divergence is a feature, not noise. Surface the most distinctive
 * things ONE side loves and the other has no trace of - those make the best
 * conversation prompts.
 */
export function collectDivergenceHighlights(
  a: UserTasteProfile,
  b: UserTasteProfile,
  popularity: PopularityIndex,
  limit = 4,
): DivergenceHighlight[] {
  const out: DivergenceHighlight[] = [];

  const oneWay = (from: UserTasteProfile, to: UserTasteProfile) => {
    for (const domain of DOMAINS) {
      if (!from[domain].present || !to[domain].present) continue;
      const toKeys = new Set(to[domain].items.map((i) => i.key));
      for (const item of from[domain].items) {
        if (toKeys.has(item.key)) continue;
        out.push({
          domain,
          key: item.key,
          label: item.label,
          heldBy: from.userId,
          weight: rarityWeight(item.key, popularity),
        });
      }
    }
  };

  oneWay(a, b);
  oneWay(b, a);

  // Interleave by holder so the UI never shows four items all from one side.
  const byA = out.filter((d) => d.heldBy === a.userId).sort((x, y) => y.weight - x.weight);
  const byB = out.filter((d) => d.heldBy === b.userId).sort((x, y) => y.weight - x.weight);
  const mixed: DivergenceHighlight[] = [];
  for (let i = 0; mixed.length < limit && (i < byA.length || i < byB.length); i++) {
    if (byA[i]) mixed.push(byA[i]!);
    if (mixed.length < limit && byB[i]) mixed.push(byB[i]!);
  }
  return mixed;
}

export function computeCompatibility(
  a: UserTasteProfile,
  b: UserTasteProfile,
  popularity: PopularityIndex,
): CompatibilityResult {
  const scores: Record<Domain, DomainScore> = {
    music: scoreDomain(a.music, b.music, popularity),
    movie: scoreDomain(a.movie, b.movie, popularity),
    book: scoreDomain(a.book, b.book, popularity),
  };

  const weights = effectiveWeights(a, b, scores);
  const overall = DOMAINS.reduce((sum, d) => sum + scores[d].score * weights[d], 0);

  return {
    overallScore: Math.round(overall),
    music: scores.music,
    movie: scores.movie,
    book: scores.book,
    weights,
    sharedHighlights: collectSharedHighlights(a, b, popularity),
    divergenceHighlights: collectDivergenceHighlights(a, b, popularity),
  };
}
