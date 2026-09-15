import type { Db } from '../db/index.js';
import { ApiError } from '../lib/errors.js';
import { newId } from '../lib/ids.js';
import { loadTasteProfile } from './tasteVector.js';

/**
 * Proposal 4.1: niche, tag-based groups users congregate in.
 *
 * Suggestions are computed from the user's own taste vector rather than asked
 * for — a community's `tags` are matched against the genres and creators
 * already in someone's profile, so the ranking explains itself.
 */

export interface Community {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  domain: string | null;
  tags: string[];
  accent: string | null;
  memberCount: number;
  joined: boolean;
  /** Only set on suggestions: which of the user's own tags pulled them here. */
  matchedTags?: string[];
}

function parseTags(raw: unknown): string[] {
  if (!raw) return [];
  const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
  return Array.isArray(parsed) ? (parsed as string[]) : [];
}

function toCommunity(row: Record<string, any>): Community {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    description: row.description,
    domain: row.domain,
    tags: parseTags(row.tags),
    accent: row.accent,
    memberCount: Number(row.member_count ?? 0),
    joined: Boolean(row.joined),
  };
}

const COMMUNITY_SELECT = `
  SELECT c.*,
         (SELECT count(*) FROM community_members m WHERE m.community_id = c.id)::int
           AS member_count,
         EXISTS (SELECT 1 FROM community_members m
                  WHERE m.community_id = c.id AND m.user_id = $1) AS joined
    FROM communities c`;

export async function listCommunities(db: Db, viewerId: string): Promise<Community[]> {
  const { rows } = await db.query<Record<string, any>>(
    `${COMMUNITY_SELECT} ORDER BY member_count DESC, c.name ASC`,
    [viewerId],
  );
  return rows.map(toCommunity);
}

export async function getCommunity(
  db: Db,
  viewerId: string,
  slug: string,
): Promise<Community> {
  const { rows } = await db.query<Record<string, any>>(
    `${COMMUNITY_SELECT} WHERE c.slug = $2`,
    [viewerId, slug],
  );
  if (!rows[0]) throw ApiError.notFound('community_not_found', 'No such community.');
  return toCommunity(rows[0]);
}

/** The signed-in user's own taste vocabulary: genres plus creators. */
async function tasteVocabulary(db: Db, userId: string): Promise<Set<string>> {
  const profile = await loadTasteProfile(db, userId);
  const vocabulary = new Set<string>();

  for (const domain of [profile.music, profile.movie, profile.book]) {
    for (const key of Object.keys(domain.vector)) {
      vocabulary.add(key.startsWith('by:') ? key.slice(3) : key);
    }
    for (const item of domain.items) vocabulary.add(item.label.toLowerCase());
  }
  return vocabulary;
}

/**
 * Communities the user isn't in yet, ranked by how many of their own taste
 * tags the community matches.
 */
export async function suggestCommunities(
  db: Db,
  viewerId: string,
  limit = 6,
): Promise<Community[]> {
  const vocabulary = await tasteVocabulary(db, viewerId);
  const all = await listCommunities(db, viewerId);

  const scored = all
    .filter((c) => !c.joined)
    .map((community) => {
      const matched = community.tags.filter((tag) => vocabulary.has(tag.toLowerCase()));
      return { community: { ...community, matchedTags: matched }, score: matched.length };
    })
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score || b.community.memberCount - a.community.memberCount);

  // If nothing matches yet (empty taste profile), fall back to the busiest
  // rooms rather than showing nothing at all.
  if (scored.length === 0) {
    return all.filter((c) => !c.joined).slice(0, limit);
  }
  return scored.slice(0, limit).map((entry) => entry.community);
}

export async function joinCommunity(db: Db, userId: string, id: string): Promise<void> {
  const { rows } = await db.query<{ id: string }>('SELECT id FROM communities WHERE id = $1', [
    id,
  ]);
  if (!rows[0]) throw ApiError.notFound('community_not_found', 'No such community.');
  await db.query(
    'INSERT INTO community_members (community_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
    [id, userId],
  );
}

export async function leaveCommunity(db: Db, userId: string, id: string): Promise<void> {
  await db.query('DELETE FROM community_members WHERE community_id = $1 AND user_id = $2', [
    id,
    userId,
  ]);
}

export interface CommunityMember {
  id: string;
  name: string | null;
  age: number | null;
  city: string | null;
  photoUrl: string | null;
}

export async function listMembers(
  db: Db,
  communityId: string,
  limit = 60,
): Promise<CommunityMember[]> {
  const { rows } = await db.query<Record<string, any>>(
    `SELECT u.id, u.name, u.age, u.city, u.photo_url
       FROM community_members m
       JOIN users u ON u.id = m.user_id
      WHERE m.community_id = $1
      ORDER BY m.joined_at DESC
      LIMIT $2`,
    [communityId, limit],
  );
  return rows.map((r) => ({
    id: r.id,
    name: r.name,
    age: r.age,
    city: r.city,
    photoUrl: r.photo_url,
  }));
}

export async function createCommunity(
  db: Db,
  input: { slug: string; name: string; description?: string; domain?: string; tags: string[]; accent?: string },
): Promise<string> {
  const id = newId();
  await db.query(
    `INSERT INTO communities (id, slug, name, description, domain, tags, accent)
     VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7)
     ON CONFLICT (slug) DO UPDATE
       SET name = EXCLUDED.name,
           description = EXCLUDED.description,
           domain = EXCLUDED.domain,
           tags = EXCLUDED.tags,
           accent = EXCLUDED.accent`,
    [
      id,
      input.slug,
      input.name,
      input.description ?? null,
      input.domain ?? null,
      JSON.stringify(input.tags),
      input.accent ?? null,
    ],
  );
  return id;
}
