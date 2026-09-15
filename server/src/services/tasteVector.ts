import type { Db } from '../db/index.js';
import type {
  Domain,
  DomainProfile,
  PopularityIndex,
  UserTasteProfile,
  Vector,
} from './compatibility/index.js';
import type { TasteItem } from './taste.js';

const DOMAINS: readonly Domain[] = ['music', 'movie', 'book'] as const;

const DOMAIN_TABLE: Record<Domain, { table: string; column: string }> = {
  music: { table: 'music_profile', column: 'top_artists' },
  movie: { table: 'movie_profile', column: 'favorite_films' },
  book: { table: 'book_profile', column: 'favorite_books' },
};

/** Groups a year into a decade bucket for the era distribution. */
function decadeOf(year: number): string {
  return `${Math.floor(year / 10) * 10}s`;
}

/**
 * Turns a user's stored favourites into the vectors the compatibility engine
 * expects. This is the only place that knows about both shapes, which keeps
 * the engine itself free of storage concerns.
 */
export function buildDomainProfile(items: TasteItem[]): DomainProfile {
  const vector: Vector = {};
  const styleVector: Vector = {};

  for (const item of items) {
    const meta = item.meta;
    for (const genre of meta?.genres ?? []) {
      vector[genre] = (vector[genre] ?? 0) + 1;
    }
    // The author/director is itself a taste axis - two people who both love a
    // director share more than two who merely both like "drama".
    if (meta?.creator) {
      const key = `by:${meta.creator.toLowerCase()}`;
      vector[key] = (vector[key] ?? 0) + 1.5;
    }
    if (meta?.year && Number.isFinite(meta.year)) {
      const bucket = decadeOf(meta.year);
      styleVector[bucket] = (styleVector[bucket] ?? 0) + 1;
    }
  }

  return {
    vector,
    styleVector,
    items: items.map((i) => ({ key: i.key, label: i.label })),
    present: items.length > 0,
  };
}

function parseItems(raw: unknown): TasteItem[] {
  if (!raw) return [];
  const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
  return Array.isArray(parsed) ? (parsed as TasteItem[]) : [];
}

export async function loadTasteProfile(db: Db, userId: string): Promise<UserTasteProfile> {
  const domains = {} as Record<Domain, DomainProfile>;

  for (const domain of DOMAINS) {
    const { table, column } = DOMAIN_TABLE[domain];
    const { rows } = await db.query<Record<string, unknown>>(
      `SELECT ${column} AS items FROM ${table} WHERE user_id = $1`,
      [userId],
    );
    domains[domain] = buildDomainProfile(parseItems(rows[0]?.items));
  }

  const { rows: userRows } = await db.query<{ domain_priority: unknown }>(
    'SELECT domain_priority FROM users WHERE id = $1',
    [userId],
  );
  const rawPriority = userRows[0]?.domain_priority;
  const priority = (typeof rawPriority === 'string' ? JSON.parse(rawPriority) : rawPriority) as
    | Record<string, number>
    | undefined;

  return {
    userId,
    music: domains.music,
    movie: domains.movie,
    book: domains.book,
    domainPriority: {
      music: priority?.music ?? 1,
      movie: priority?.movie ?? 1,
      book: priority?.book ?? 1,
    },
  };
}

/** Platform-wide favourite counts, for the inverse-popularity weighting. */
export async function loadPopularityIndex(db: Db): Promise<PopularityIndex> {
  const { rows: userCount } = await db.query<{ count: string }>(
    'SELECT count(*)::text AS count FROM users',
  );
  const { rows } = await db.query<{ item_key: string; user_count: number }>(
    'SELECT item_key, user_count FROM item_popularity',
  );

  const counts: Record<string, number> = {};
  for (const row of rows) counts[row.item_key] = Number(row.user_count);

  return { totalUsers: Math.max(Number(userCount[0]?.count ?? 1), 1), counts };
}
