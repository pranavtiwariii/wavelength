import type { Db } from '../db/index.js';
import { ApiError } from '../lib/errors.js';
import { providers, type Domain, type TasteSearchResult } from './integrations/index.js';

/** Where each domain's favourites live, and how many make a domain "done". */
const DOMAIN_TABLE: Record<Domain, { table: string; column: string }> = {
  music: { table: 'music_profile', column: 'top_artists' },
  movie: { table: 'movie_profile', column: 'favorite_films' },
  book: { table: 'book_profile', column: 'favorite_books' },
};

const DOMAINS: readonly Domain[] = ['music', 'movie', 'book'] as const;

/** A domain counts as fully imported at this many favourites. */
export const TARGET_ITEMS_PER_DOMAIN = 5;

export interface TasteItemMeta {
  genres?: string[];
  year?: number;
  creator?: string;
}

export interface TasteItem {
  key: string;
  label: string;
  subtitle?: string;
  imageUrl?: string;
  meta?: TasteItemMeta;
  addedAt: string;
}

export function assertDomain(value: string): Domain {
  if (value !== 'music' && value !== 'movie' && value !== 'book') {
    throw ApiError.badRequest('unknown_domain', `Unknown taste domain "${value}".`);
  }
  return value;
}

export async function searchTaste(domain: Domain, query: string): Promise<TasteSearchResult[]> {
  const provider = providers[domain];
  if (!provider.available) {
    throw ApiError.badRequest(
      'provider_unavailable',
      provider.unavailableReason ?? `${provider.name} is not configured.`,
    );
  }
  if (query.trim().length < 2) return [];

  try {
    return await provider.search(query.trim());
  } catch (err) {
    // Never surface a third-party outage as a 500 - it's not the user's fault
    // and the UI can offer a retry.
    throw new ApiError(
      502,
      'provider_failed',
      `${provider.name} isn't responding right now. Try again in a moment.`,
    );
  }
}

async function readItems(db: Db, userId: string, domain: Domain): Promise<TasteItem[]> {
  const { table, column } = DOMAIN_TABLE[domain];
  const { rows } = await db.query<Record<string, unknown>>(
    `SELECT ${column} AS items FROM ${table} WHERE user_id = $1`,
    [userId],
  );
  const raw = rows[0]?.items;
  if (!raw) return [];
  return (typeof raw === 'string' ? JSON.parse(raw) : raw) as TasteItem[];
}

async function writeItems(
  db: Db,
  userId: string,
  domain: Domain,
  items: TasteItem[],
): Promise<void> {
  const { table, column } = DOMAIN_TABLE[domain];
  await db.query(
    `INSERT INTO ${table} (user_id, ${column}, source, last_synced_at)
     VALUES ($1, $2::jsonb, 'manual', now())
     ON CONFLICT (user_id) DO UPDATE
       SET ${column} = EXCLUDED.${column},
           source = 'manual',
           last_synced_at = now()`,
    [userId, JSON.stringify(items)],
  );
}

/**
 * Spec 3.1: each domain contributes a third of the meter, scaled by how far
 * toward TARGET_ITEMS_PER_DOMAIN the user has got - so progress moves on the
 * first add rather than jumping in thirds.
 */
export function computeCompleteness(counts: Record<Domain, number>): number {
  const perDomain = DOMAINS.map((d) => Math.min(counts[d] / TARGET_ITEMS_PER_DOMAIN, 1));
  const total = perDomain.reduce((sum, x) => sum + x, 0) / DOMAINS.length;
  return Math.round(total * 100);
}

async function refreshCompleteness(db: Db, userId: string): Promise<number> {
  const counts = {} as Record<Domain, number>;
  for (const domain of DOMAINS) {
    counts[domain] = (await readItems(db, userId, domain)).length;
  }
  const completeness = computeCompleteness(counts);
  await db.query(
    'UPDATE users SET taste_profile_completeness = $2, updated_at = now() WHERE id = $1',
    [userId, completeness],
  );
  return completeness;
}

export interface TasteProfileView {
  completeness: number;
  domains: Record<
    Domain,
    {
      items: TasteItem[];
      available: boolean;
      providerName: string;
      unavailableReason?: string;
      target: number;
    }
  >;
}

export async function getTasteProfile(db: Db, userId: string): Promise<TasteProfileView> {
  const domains = {} as TasteProfileView['domains'];
  const counts = {} as Record<Domain, number>;

  for (const domain of DOMAINS) {
    const items = await readItems(db, userId, domain);
    counts[domain] = items.length;
    const provider = providers[domain];
    domains[domain] = {
      items,
      available: provider.available,
      providerName: provider.name,
      target: TARGET_ITEMS_PER_DOMAIN,
      ...(provider.available ? {} : { unavailableReason: provider.unavailableReason }),
    };
  }

  return { completeness: computeCompleteness(counts), domains };
}

export async function addTasteItem(
  db: Db,
  userId: string,
  domain: Domain,
  item: Omit<TasteItem, 'addedAt'>,
): Promise<TasteProfileView> {
  const items = await readItems(db, userId, domain);
  if (items.some((existing) => existing.key === item.key)) {
    throw ApiError.badRequest('already_added', `${item.label} is already on your list.`);
  }
  if (items.length >= 50) {
    throw ApiError.badRequest('too_many_items', 'You can keep up to 50 favourites per domain.');
  }

  items.push({ ...item, addedAt: new Date().toISOString() });
  await writeItems(db, userId, domain, items);
  await bumpPopularity(db, domain, item.key, 1);
  await refreshCompleteness(db, userId);
  return getTasteProfile(db, userId);
}

export async function removeTasteItem(
  db: Db,
  userId: string,
  domain: Domain,
  key: string,
): Promise<TasteProfileView> {
  const items = await readItems(db, userId, domain);
  const next = items.filter((item) => item.key !== key);
  if (next.length === items.length) {
    throw ApiError.notFound('item_not_found', 'That item is not on your list.');
  }

  await writeItems(db, userId, domain, next);
  await bumpPopularity(db, domain, key, -1);
  await refreshCompleteness(db, userId);
  return getTasteProfile(db, userId);
}

/**
 * Keeps item_popularity current so the compatibility engine's inverse-popularity
 * weighting (spec 5.2) has real counts to work with.
 */
async function bumpPopularity(db: Db, domain: Domain, key: string, delta: number): Promise<void> {
  await db.query(
    `INSERT INTO item_popularity (domain, item_key, user_count, updated_at)
     VALUES ($1, $2, GREATEST($3, 0), now())
     ON CONFLICT (domain, item_key) DO UPDATE
       SET user_count = GREATEST(item_popularity.user_count + $3, 0),
           updated_at = now()`,
    [domain, key, delta],
  );
}
