import type { Db } from '../db/index.js';
import { ApiError } from '../lib/errors.js';
import { newId } from '../lib/ids.js';
import type { Domain } from './integrations/index.js';

/**
 * Proposal 4.1: Content Drops — lightweight posts through which users share
 * and tag content they like, categorized by domain.
 */

export interface Drop {
  id: string;
  domain: Domain;
  itemKey: string;
  itemLabel: string;
  itemSubtitle: string | null;
  itemImage: string | null;
  caption: string | null;
  createdAt: string;
  author: {
    id: string;
    name: string | null;
    photoUrl: string | null;
  };
  community: { id: string; name: string; slug: string } | null;
  likeCount: number;
  saveCount: number;
  likedByMe: boolean;
  savedByMe: boolean;
  /** Set when the viewer also has this exact item in their taste profile. */
  sharedWithMe: boolean;
}

const DROP_SELECT = `
  SELECT d.id, d.domain, d.item_key, d.item_label, d.item_subtitle, d.item_image,
         d.caption, d.created_at,
         u.id AS author_id, u.name AS author_name, u.photo_url AS author_photo,
         c.id AS community_id, c.name AS community_name, c.slug AS community_slug,
         (SELECT count(*) FROM drop_reactions r
           WHERE r.drop_id = d.id AND r.kind = 'like')::int AS like_count,
         (SELECT count(*) FROM drop_reactions r
           WHERE r.drop_id = d.id AND r.kind = 'save')::int AS save_count,
         EXISTS (SELECT 1 FROM drop_reactions r
                  WHERE r.drop_id = d.id AND r.user_id = $1 AND r.kind = 'like') AS liked,
         EXISTS (SELECT 1 FROM drop_reactions r
                  WHERE r.drop_id = d.id AND r.user_id = $1 AND r.kind = 'save') AS saved
    FROM drops d
    JOIN users u ON u.id = d.user_id
    LEFT JOIN communities c ON c.id = d.community_id`;

function toDrop(row: Record<string, any>, myKeys: Set<string>): Drop {
  return {
    id: row.id,
    domain: row.domain,
    itemKey: row.item_key,
    itemLabel: row.item_label,
    itemSubtitle: row.item_subtitle,
    itemImage: row.item_image,
    caption: row.caption,
    createdAt: new Date(row.created_at).toISOString(),
    author: { id: row.author_id, name: row.author_name, photoUrl: row.author_photo },
    community: row.community_id
      ? { id: row.community_id, name: row.community_name, slug: row.community_slug }
      : null,
    likeCount: Number(row.like_count ?? 0),
    saveCount: Number(row.save_count ?? 0),
    likedByMe: Boolean(row.liked),
    savedByMe: Boolean(row.saved),
    sharedWithMe: myKeys.has(row.item_key),
  };
}

/** Every item key in the viewer's own taste profile, for the "you too" flag. */
async function myItemKeys(db: Db, userId: string): Promise<Set<string>> {
  const { rows } = await db.query<Record<string, any>>(
    `SELECT COALESCE(m.top_artists, '[]'::jsonb) AS music,
            COALESCE(mo.favorite_films, '[]'::jsonb) AS movie,
            COALESCE(b.favorite_books, '[]'::jsonb) AS book
       FROM users u
       LEFT JOIN music_profile m ON m.user_id = u.id
       LEFT JOIN movie_profile mo ON mo.user_id = u.id
       LEFT JOIN book_profile b ON b.user_id = u.id
      WHERE u.id = $1`,
    [userId],
  );
  const row = rows[0];
  if (!row) return new Set();

  const keys = new Set<string>();
  for (const column of ['music', 'movie', 'book'] as const) {
    const raw = row[column];
    const items = typeof raw === 'string' ? JSON.parse(raw) : raw;
    for (const item of (items ?? []) as Array<{ key?: string }>) {
      if (item.key) keys.add(item.key);
    }
  }
  return keys;
}

export async function listFeed(db: Db, viewerId: string, limit = 40): Promise<Drop[]> {
  const myKeys = await myItemKeys(db, viewerId);
  const { rows } = await db.query<Record<string, any>>(
    `${DROP_SELECT}
      WHERE NOT EXISTS (
        SELECT 1 FROM blocks bl
         WHERE (bl.blocker_id = $1 AND bl.blocked_id = d.user_id)
            OR (bl.blocker_id = d.user_id AND bl.blocked_id = $1))
      ORDER BY d.created_at DESC
      LIMIT $2`,
    [viewerId, limit],
  );
  return rows.map((r) => toDrop(r, myKeys));
}

export async function listCommunityDrops(
  db: Db,
  viewerId: string,
  communityId: string,
  limit = 40,
): Promise<Drop[]> {
  const myKeys = await myItemKeys(db, viewerId);
  const { rows } = await db.query<Record<string, any>>(
    `${DROP_SELECT} WHERE d.community_id = $2 ORDER BY d.created_at DESC LIMIT $3`,
    [viewerId, communityId, limit],
  );
  return rows.map((r) => toDrop(r, myKeys));
}

export async function listUserDrops(
  db: Db,
  viewerId: string,
  userId: string,
): Promise<Drop[]> {
  const myKeys = await myItemKeys(db, viewerId);
  const { rows } = await db.query<Record<string, any>>(
    `${DROP_SELECT} WHERE d.user_id = $2 ORDER BY d.created_at DESC LIMIT 40`,
    [viewerId, userId],
  );
  return rows.map((r) => toDrop(r, myKeys));
}

/** Drops the viewer has saved, newest save first. */
export async function listSaved(db: Db, viewerId: string): Promise<Drop[]> {
  const myKeys = await myItemKeys(db, viewerId);
  const { rows } = await db.query<Record<string, any>>(
    `${DROP_SELECT}
       JOIN drop_reactions saved
         ON saved.drop_id = d.id AND saved.user_id = $1 AND saved.kind = 'save'
      ORDER BY saved.created_at DESC`,
    [viewerId],
  );
  return rows.map((r) => toDrop(r, myKeys));
}

export interface CreateDropInput {
  domain: Domain;
  itemKey: string;
  itemLabel: string;
  itemSubtitle?: string;
  itemImage?: string;
  caption?: string;
  communityId?: string;
}

export async function createDrop(
  db: Db,
  userId: string,
  input: CreateDropInput,
): Promise<Drop> {
  if (input.communityId) {
    const { rows } = await db.query<{ community_id: string }>(
      'SELECT community_id FROM community_members WHERE community_id = $1 AND user_id = $2',
      [input.communityId, userId],
    );
    if (rows.length === 0) {
      throw ApiError.forbidden('not_a_member', 'Join the community before posting in it.');
    }
  }

  const id = newId();
  await db.query(
    `INSERT INTO drops (id, user_id, domain, item_key, item_label, item_subtitle,
                        item_image, caption, community_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
    [
      id,
      userId,
      input.domain,
      input.itemKey,
      input.itemLabel,
      input.itemSubtitle ?? null,
      input.itemImage ?? null,
      input.caption?.trim() || null,
      input.communityId ?? null,
    ],
  );

  const myKeys = await myItemKeys(db, userId);
  const { rows } = await db.query<Record<string, any>>(`${DROP_SELECT} WHERE d.id = $2`, [
    userId,
    id,
  ]);
  return toDrop(rows[0]!, myKeys);
}

export async function react(
  db: Db,
  userId: string,
  dropId: string,
  kind: 'like' | 'save',
  on: boolean,
): Promise<void> {
  if (on) {
    await db.query(
      `INSERT INTO drop_reactions (drop_id, user_id, kind) VALUES ($1,$2,$3)
       ON CONFLICT DO NOTHING`,
      [dropId, userId, kind],
    );

    // A save is private; only a like is worth telling the author about.
    if (kind === 'like') {
      const { rows } = await db.query<{ user_id: string; item_label: string }>(
        'SELECT user_id, item_label FROM drops WHERE id = $1',
        [dropId],
      );
      const drop = rows[0];
      if (drop) {
        const { emit, nameOf } = await import('./notifications.js');
        await emit(db, {
          userId: drop.user_id,
          kind: 'drop_like',
          actorId: userId,
          target: '/drops',
          body: `${await nameOf(db, userId)} liked your drop of ${drop.item_label}`,
        });
      }
    }
  } else {
    await db.query(
      'DELETE FROM drop_reactions WHERE drop_id = $1 AND user_id = $2 AND kind = $3',
      [dropId, userId, kind],
    );
  }
}

export async function deleteDrop(db: Db, userId: string, dropId: string): Promise<void> {
  const { rows } = await db.query<{ user_id: string }>(
    'SELECT user_id FROM drops WHERE id = $1',
    [dropId],
  );
  if (!rows[0]) throw ApiError.notFound('drop_not_found', 'That drop no longer exists.');
  if (rows[0].user_id !== userId) {
    throw ApiError.forbidden('not_yours', 'You can only delete your own drops.');
  }
  await db.query('DELETE FROM drops WHERE id = $1', [dropId]);
}
