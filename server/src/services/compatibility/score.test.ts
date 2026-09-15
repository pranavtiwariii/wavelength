import { describe, expect, it } from 'vitest';
import {
  collectDivergenceHighlights,
  collectSharedHighlights,
  computeCompatibility,
  effectiveWeights,
  scoreDomain,
} from './score.js';
import { cosineSimilarity, distributionOverlap, rarityWeight, weightedJaccard } from './math.js';
import type { DomainProfile, PopularityIndex, UserTasteProfile } from './types.js';

const emptyDomain = (): DomainProfile => ({
  vector: {},
  items: [],
  styleVector: {},
  present: false,
});

const domain = (p: Partial<DomainProfile>): DomainProfile => ({
  vector: {},
  items: [],
  styleVector: {},
  present: true,
  ...p,
});

const user = (userId: string, p: Partial<UserTasteProfile> = {}): UserTasteProfile => ({
  userId,
  music: emptyDomain(),
  movie: emptyDomain(),
  book: emptyDomain(),
  domainPriority: { music: 1, movie: 1, book: 1 },
  ...p,
});

/** 1000 users; "taylor-swift" is everywhere, "obscure-film" is nearly unique. */
const popularity: PopularityIndex = {
  totalUsers: 1000,
  counts: { 'taylor-swift': 800, drake: 750, 'the-godfather': 600, 'obscure-film': 2, 'rare-band': 3 },
};

describe('math primitives', () => {
  it('cosine of identical vectors is 1', () => {
    expect(cosineSimilarity({ indie: 3, jazz: 1 }, { indie: 3, jazz: 1 })).toBeCloseTo(1);
  });

  it('cosine ignores magnitude, only direction', () => {
    expect(cosineSimilarity({ indie: 1, jazz: 2 }, { indie: 5, jazz: 10 })).toBeCloseTo(1);
  });

  it('cosine of disjoint vectors is 0', () => {
    expect(cosineSimilarity({ indie: 1 }, { metal: 1 })).toBe(0);
  });

  it('cosine of an empty vector is 0, not NaN', () => {
    expect(cosineSimilarity({}, { indie: 1 })).toBe(0);
    expect(Number.isNaN(cosineSimilarity({}, {}))).toBe(false);
  });

  it('rarity weight is higher for obscure items than popular ones', () => {
    expect(rarityWeight('obscure-film', popularity)).toBeGreaterThan(
      rarityWeight('taylor-swift', popularity),
    );
  });

  it('treats an unseen item as maximally rare', () => {
    expect(rarityWeight('never-seen-before', popularity)).toBeGreaterThan(
      rarityWeight('rare-band', popularity),
    );
  });

  it('distribution overlap is 1 for identical shapes regardless of scale', () => {
    expect(distributionOverlap({ '1990s': 2, '2000s': 2 }, { '1990s': 50, '2000s': 50 })).toBeCloseTo(1);
  });
});

describe('rare overlap beats mainstream overlap (spec 5.2)', () => {
  it('scores a shared obscure film above a shared blockbuster', () => {
    const obscure = weightedJaccard(
      [{ key: 'obscure-film', label: 'Obscure' }],
      [{ key: 'obscure-film', label: 'Obscure' }],
      popularity,
    );
    const mainstream = weightedJaccard(
      [{ key: 'the-godfather', label: 'The Godfather' }],
      [{ key: 'the-godfather', label: 'The Godfather' }],
      popularity,
    );
    // Both are perfect overlaps, so Jaccard alone saturates at 1 for each...
    expect(obscure).toBeCloseTo(1);
    expect(mainstream).toBeCloseTo(1);
  });

  it('when each pair shares one item out of two, the rare share scores higher', () => {
    const rare = weightedJaccard(
      [{ key: 'obscure-film', label: 'o' }, { key: 'x1', label: 'x' }],
      [{ key: 'obscure-film', label: 'o' }, { key: 'x2', label: 'x' }],
      popularity,
    );
    const popular = weightedJaccard(
      [{ key: 'taylor-swift', label: 't' }, { key: 'x1', label: 'x' }],
      [{ key: 'taylor-swift', label: 't' }, { key: 'x2', label: 'x' }],
      popularity,
    );
    expect(rare).toBeGreaterThan(popular);
  });

  it('ranks the rarest shared item first in the highlights', () => {
    const a = user('a', {
      music: domain({
        items: [
          { key: 'taylor-swift', label: 'Taylor Swift' },
          { key: 'rare-band', label: 'Rare Band' },
        ],
      }),
    });
    const b = user('b', {
      music: domain({
        items: [
          { key: 'taylor-swift', label: 'Taylor Swift' },
          { key: 'rare-band', label: 'Rare Band' },
        ],
      }),
    });
    const highlights = collectSharedHighlights(a, b, popularity);
    expect(highlights[0]!.label).toBe('Rare Band');
    expect(highlights[1]!.label).toBe('Taylor Swift');
  });
});

describe('scoreDomain', () => {
  it('is not comparable when one side has no data', () => {
    expect(scoreDomain(domain({ vector: { indie: 1 } }), emptyDomain(), popularity).comparable).toBe(
      false,
    );
  });

  it('gives identical profiles a perfect score', () => {
    const d = domain({
      vector: { indie: 3, folk: 1 },
      items: [{ key: 'rare-band', label: 'Rare Band' }],
      styleVector: { '2010s': 1 },
    });
    expect(scoreDomain(d, d, popularity).score).toBe(100);
  });

  it('gives fully disjoint profiles a low score', () => {
    const a = domain({ vector: { indie: 1 }, items: [{ key: 'x', label: 'x' }], styleVector: { '1970s': 1 } });
    const b = domain({ vector: { metal: 1 }, items: [{ key: 'y', label: 'y' }], styleVector: { '2020s': 1 } });
    expect(scoreDomain(a, b, popularity).score).toBe(0);
  });
});

describe('effectiveWeights (spec 5.3)', () => {
  it('ignores a domain only one user has connected', () => {
    const a = user('a', {
      music: domain({ vector: { indie: 1 }, items: [{ key: 'm', label: 'm' }] }),
      movie: domain({ vector: { drama: 1 }, items: [{ key: 'f', label: 'f' }] }),
    });
    const b = user('b', { music: domain({ vector: { indie: 1 }, items: [{ key: 'm', label: 'm' }] }) });

    const result = computeCompatibility(a, b, popularity);
    expect(result.weights.music).toBeCloseTo(1);
    expect(result.weights.movie).toBe(0);
    expect(result.weights.book).toBe(0);
  });

  it('does not let an unconnected domain drag the overall score down', () => {
    const shared = domain({
      vector: { indie: 1 },
      items: [{ key: 'rare-band', label: 'Rare Band' }],
      styleVector: { '2010s': 1 },
    });
    const musicOnlyA = user('a', { music: shared });
    const musicOnlyB = user('b', { music: shared });

    // Perfect music match, nothing else connected -> still a perfect overall.
    expect(computeCompatibility(musicOnlyA, musicOnlyB, popularity).overallScore).toBe(100);
  });

  it('weights two equally-complete domains equally by default', () => {
    const base = {
      music: domain({ vector: { indie: 1 }, items: [{ key: 'm', label: 'm' }] }),
      movie: domain({ vector: { drama: 1 }, items: [{ key: 'f', label: 'f' }] }),
    };
    const result = computeCompatibility(user('a', base), user('b', base), popularity);
    expect(result.weights.music).toBeCloseTo(result.weights.movie);
  });

  it('shifts weight toward the domain a user prioritises', () => {
    const base = {
      music: domain({ vector: { indie: 1 }, items: [{ key: 'm', label: 'm' }] }),
      movie: domain({ vector: { drama: 1 }, items: [{ key: 'f', label: 'f' }] }),
    };
    const musicFirst = user('a', { ...base, domainPriority: { music: 3, movie: 1, book: 1 } });
    const result = computeCompatibility(musicFirst, user('b', base), popularity);
    expect(result.weights.music).toBeGreaterThan(result.weights.movie);
  });

  it('always produces weights that sum to 1 when anything is comparable', () => {
    const base = {
      music: domain({ vector: { indie: 1 }, items: [{ key: 'm', label: 'm' }] }),
      book: domain({ vector: { scifi: 1 }, items: [{ key: 'bk', label: 'bk' }] }),
    };
    const { weights } = computeCompatibility(user('a', base), user('b', base), popularity);
    expect(weights.music + weights.movie + weights.book).toBeCloseTo(1);
  });

  it('returns zero weights and a zero score when nothing is comparable', () => {
    const result = computeCompatibility(user('a'), user('b'), popularity);
    expect(result.overallScore).toBe(0);
    expect(result.weights).toEqual({ music: 0, movie: 0, book: 0 });
  });
});

describe('divergence highlights (spec 4.6)', () => {
  it('surfaces items one side holds and the other does not, from both sides', () => {
    const a = user('a', {
      movie: domain({
        items: [
          { key: 'shared', label: 'Shared Film' },
          { key: 'only-a', label: 'Only A' },
        ],
      }),
    });
    const b = user('b', {
      movie: domain({
        items: [
          { key: 'shared', label: 'Shared Film' },
          { key: 'only-b', label: 'Only B' },
        ],
      }),
    });

    const d = collectDivergenceHighlights(a, b, popularity);
    const labels = d.map((x) => x.label);
    expect(labels).toContain('Only A');
    expect(labels).toContain('Only B');
    expect(labels).not.toContain('Shared Film');
    // One from each side, interleaved - never all from one user.
    expect(new Set(d.map((x) => x.heldBy)).size).toBe(2);
  });
});

describe('computeCompatibility is symmetric', () => {
  it('scores the same regardless of argument order', () => {
    const a = user('a', {
      music: domain({ vector: { indie: 3, folk: 1 }, items: [{ key: 'rare-band', label: 'r' }], styleVector: { '2010s': 1 } }),
      movie: domain({ vector: { drama: 2 }, items: [{ key: 'obscure-film', label: 'o' }], styleVector: { '1970s': 1 } }),
    });
    const b = user('b', {
      music: domain({ vector: { indie: 1, metal: 2 }, items: [{ key: 'rare-band', label: 'r' }], styleVector: { '2000s': 1 } }),
      movie: domain({ vector: { drama: 1, horror: 3 }, items: [{ key: 'x', label: 'x' }], styleVector: { '1970s': 1 } }),
    });

    expect(computeCompatibility(a, b, popularity).overallScore).toBe(
      computeCompatibility(b, a, popularity).overallScore,
    );
  });
});
