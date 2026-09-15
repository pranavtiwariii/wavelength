import type { Db } from '../db/index.js';
import type { Domain } from './integrations/index.js';

/**
 * Curated picks shown during onboarding, so the first taste selection is a few
 * taps rather than five searches.
 *
 * These are read back out of the seeded profiles, which means the keys are the
 * exact ones the providers returned — a user who taps "Radiohead" here gets the
 * identical item key a seeded person has, and they genuinely overlap. Curating
 * a hand-written list would silently break that.
 */
export interface StarterItem {
  key: string;
  label: string;
  subtitle?: string;
  imageUrl?: string;
  meta?: { genres?: string[]; year?: number; creator?: string };
  /** How many people in the pool already have it — drives ordering. */
  popularity: number;
}

const DOMAIN_SOURCE: Record<Domain, { table: string; column: string }> = {
  music: { table: 'music_profile', column: 'top_artists' },
  movie: { table: 'movie_profile', column: 'favorite_films' },
  book: { table: 'book_profile', column: 'favorite_books' },
};

export async function listStarters(
  db: Db,
  domain: Domain,
  limit = 24,
): Promise<StarterItem[]> {
  const { table, column } = DOMAIN_SOURCE[domain];
  const { rows } = await db.query<Record<string, unknown>>(
    `SELECT ${column} AS items FROM ${table}`,
  );

  const byKey = new Map<string, StarterItem>();
  for (const row of rows) {
    const raw = row.items;
    const items = (typeof raw === 'string' ? JSON.parse(raw) : raw) as
      | Array<Record<string, any>>
      | null;

    for (const item of items ?? []) {
      if (!item?.key || !item?.label) continue;
      const existing = byKey.get(item.key);
      if (existing) {
        existing.popularity++;
        continue;
      }
      byKey.set(item.key, {
        key: item.key,
        label: item.label,
        ...(item.subtitle ? { subtitle: item.subtitle } : {}),
        ...(item.imageUrl ? { imageUrl: item.imageUrl } : {}),
        ...(item.meta ? { meta: item.meta } : {}),
        popularity: 1,
      });
    }
  }

  return [...byKey.values()]
    .sort((a, b) => b.popularity - a.popularity || a.label.localeCompare(b.label))
    .slice(0, limit);
}
