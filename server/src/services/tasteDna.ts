import type { PopularityIndex, UserTasteProfile } from './compatibility/index.js';
import { clamp01 } from './compatibility/math.js';

/**
 * Spec 4.1: five axes derived from the data, never self-reported - everyone
 * thinks they're eclectic. Each is 0..1, where 1 is the second-named pole.
 */
export const DNA_AXES = [
  'niche', // Mainstream <-> Niche
  'melancholic', // Upbeat <-> Melancholic
  'contemporary', // Classic <-> Contemporary
  'maximalist', // Minimalist <-> Maximalist
  'challenging', // Comfort <-> Challenging
] as const;

export type DnaAxis = (typeof DNA_AXES)[number];
export type TasteDna = Record<DnaAxis, number>;

/** Genre words that read as melancholic, challenging, or maximalist. */
const MELANCHOLIC = /sad|melancho|slowcore|shoegaze|ambient|tragedy|drama|elegy|blues|requiem|noir/;
const CHALLENGING = /experiment|avant|art house|arthouse|noise|abstract|philosoph|surreal|post-|free jazz|literary/;
const MAXIMALIST = /orchestr|symphon|epic|maximal|prog|opera|baroque|metal|spectacle|blockbuster/;

function allItems(profile: UserTasteProfile) {
  return [...profile.music.items, ...profile.movie.items, ...profile.book.items];
}

function allGenres(profile: UserTasteProfile): string[] {
  return [
    ...Object.keys(profile.music.vector),
    ...Object.keys(profile.movie.vector),
    ...Object.keys(profile.book.vector),
  ].filter((k) => !k.startsWith('by:'));
}

function eraYears(profile: UserTasteProfile): number[] {
  const years: number[] = [];
  for (const domain of [profile.music, profile.movie, profile.book]) {
    for (const [bucket, weight] of Object.entries(domain.styleVector)) {
      const decade = Number(bucket.replace('s', ''));
      if (!Number.isFinite(decade)) continue;
      for (let i = 0; i < weight; i++) years.push(decade);
    }
  }
  return years;
}

function ratio(list: string[], pattern: RegExp): number {
  if (list.length === 0) return 0.5;
  return list.filter((g) => pattern.test(g)).length / list.length;
}

export function computeTasteDna(
  profile: UserTasteProfile,
  popularity: PopularityIndex,
): TasteDna {
  const items = allItems(profile);
  const genres = allGenres(profile);

  // Niche: how rarely other users share these favourites.
  let niche = 0.5;
  if (items.length > 0) {
    const shares = items.map((item) => {
      const count = popularity.counts[item.key] ?? 0;
      return count / Math.max(popularity.totalUsers, 1);
    });
    const meanShare = shares.reduce((a, b) => a + b, 0) / shares.length;
    niche = clamp01(1 - meanShare * 4);
  }

  // Contemporary: mean era, mapped across 1950 -> now.
  const years = eraYears(profile);
  let contemporary = 0.5;
  if (years.length > 0) {
    const mean = years.reduce((a, b) => a + b, 0) / years.length;
    const now = new Date().getFullYear();
    contemporary = clamp01((mean - 1950) / (now - 1950));
  }

  // The remaining three read the genre vocabulary. Scaled so a modest presence
  // already moves the axis - these words are sparse by nature.
  return {
    niche,
    melancholic: clamp01(0.25 + ratio(genres, MELANCHOLIC) * 2.2),
    contemporary,
    maximalist: clamp01(0.25 + ratio(genres, MAXIMALIST) * 2.2),
    challenging: clamp01(0.2 + ratio(genres, CHALLENGING) * 2.6),
  };
}
