import type { Db } from '../db/index.js';
import { ApiError } from '../lib/errors.js';
import { newId, orderPair } from '../lib/ids.js';
import { computeCompatibility, type CompatibilityResult } from './compatibility/index.js';
import { computeTasteDna, type TasteDna } from './tasteDna.js';
import { loadPopularityIndex, loadTasteProfile } from './tasteVector.js';

export interface PublicUser {
  id: string;
  name: string | null;
  age: number | null;
  gender: string | null;
  city: string | null;
  bio: string | null;
  photoUrl: string | null;
}

export interface DiscoveryCard {
  user: PublicUser;
  overallScore: number;
  music: number | null;
  movie: number | null;
  book: number | null;
  sharedHighlights: Array<{ domain: string; label: string }>;
  divergenceHighlights: Array<{ domain: string; label: string; heldBy: string }>;
  tasteDna: TasteDna;
  yourTasteDna: TasteDna;
  narrative: string | null;
}

async function readPublicUser(db: Db, userId: string): Promise<PublicUser | null> {
  const { rows } = await db.query<Record<string, any>>(
    `SELECT u.id, u.name, u.age, u.gender, u.city, u.bio, u.photo_url,
            (SELECT url FROM user_photos p WHERE p.user_id = u.id ORDER BY position LIMIT 1)
              AS gallery_photo
       FROM users u WHERE u.id = $1`,
    [userId],
  );
  const u = rows[0];
  if (!u) return null;
  return {
    id: u.id,
    name: u.name,
    age: u.age,
    gender: u.gender ?? null,
    city: u.city,
    bio: u.bio,
    photoUrl: u.gallery_photo ?? u.photo_url ?? null,
  };
}

function domainScoreOrNull(score: { comparable: boolean; score: number }): number | null {
  return score.comparable ? score.score : null;
}

/**
 * Candidates the viewer hasn't swiped on or blocked, in their intent pool.
 * Scores are computed here for the returned page only - precomputing every
 * pair is a Phase 5 job (spec NFR 9), and this keeps the feed correct in the
 * meantime.
 */
export interface DiscoveryFilters {
  minScore?: number;
  minAge?: number;
  maxAge?: number;
}

export async function buildDiscoveryFeed(
  db: Db,
  viewerId: string,
  limit = 20,
  filters: DiscoveryFilters = {},
): Promise<DiscoveryCard[]> {
  const { rows: viewerRows } = await db.query<{
    intent: string | null;
    seeking: string | null;
  }>('SELECT intent, seeking FROM users WHERE id = $1', [viewerId]);
  const viewerIntent = viewerRows[0]?.intent ?? 'both';
  const seeking = viewerRows[0]?.seeking ?? 'everyone';

  // Gender preference applies to dating only. Someone here to make friends
  // sees everyone, by design.
  const applyGender = viewerIntent === 'dating' && seeking !== 'everyone';
  const wantedGender = seeking === 'men' ? 'man' : 'woman';

  const { rows: candidates } = await db.query<{ id: string }>(
    `SELECT u.id
       FROM users u
      WHERE u.id <> $1
        AND u.name IS NOT NULL
        AND u.taste_profile_completeness > 0
        -- Respect intent pools: 'both' mixes with everyone, otherwise match on intent.
        AND ($2 = 'both' OR u.intent = 'both' OR u.intent = $2)
        AND (NOT $3::boolean OR u.gender = $4)
        AND ($5::int IS NULL OR u.age IS NULL OR u.age >= $5::int)
        AND ($6::int IS NULL OR u.age IS NULL OR u.age <= $6::int)
        AND NOT EXISTS (SELECT 1 FROM swipes s WHERE s.actor_id = $1 AND s.target_id = u.id)
        AND NOT EXISTS (
          SELECT 1 FROM blocks b
           WHERE (b.blocker_id = $1 AND b.blocked_id = u.id)
              OR (b.blocker_id = u.id AND b.blocked_id = $1)
        )
      LIMIT 80`,
    [
      viewerId,
      viewerIntent,
      applyGender,
      wantedGender,
      filters.minAge ?? null,
      filters.maxAge ?? null,
    ],
  );

  if (candidates.length === 0) return [];

  const popularity = await loadPopularityIndex(db);
  const viewerTaste = await loadTasteProfile(db, viewerId);
  const viewerDna = computeTasteDna(viewerTaste, popularity);

  const cards: DiscoveryCard[] = [];
  for (const candidate of candidates) {
    const user = await readPublicUser(db, candidate.id);
    if (!user) continue;

    const theirTaste = await loadTasteProfile(db, candidate.id);
    const result = computeCompatibility(viewerTaste, theirTaste, popularity);

    cards.push({
      user,
      overallScore: result.overallScore,
      music: domainScoreOrNull(result.music),
      movie: domainScoreOrNull(result.movie),
      book: domainScoreOrNull(result.book),
      sharedHighlights: result.sharedHighlights.map((h) => ({ domain: h.domain, label: h.label })),
      divergenceHighlights: result.divergenceHighlights.map((d) => ({
        domain: d.domain,
        label: d.label,
        heldBy: d.heldBy,
      })),
      tasteDna: computeTasteDna(theirTaste, popularity),
      yourTasteDna: viewerDna,
      narrative: null,
    });

    await cacheScore(db, viewerId, candidate.id, result);
  }

  // Highest compatibility first, with a little jitter so the queue isn't
  // identical every session (spec 3.4).
  return cards
    .filter((c) => c.overallScore >= (filters.minScore ?? 0))
    .sort((a, b) => b.overallScore - a.overallScore + (Math.random() - 0.5) * 6)
    .slice(0, limit);
}

async function cacheScore(
  db: Db,
  a: string,
  b: string,
  result: CompatibilityResult,
): Promise<void> {
  const [userA, userB] = orderPair(a, b);
  await db.query(
    `INSERT INTO compatibility_scores
       (user_a_id, user_b_id, overall_score, music_score, movie_score, book_score,
        shared_highlights, divergence_highlights, computed_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7::jsonb,$8::jsonb, now())
     ON CONFLICT (user_a_id, user_b_id) DO UPDATE
       SET overall_score = EXCLUDED.overall_score,
           music_score = EXCLUDED.music_score,
           movie_score = EXCLUDED.movie_score,
           book_score = EXCLUDED.book_score,
           shared_highlights = EXCLUDED.shared_highlights,
           divergence_highlights = EXCLUDED.divergence_highlights,
           computed_at = now()`,
    [
      userA,
      userB,
      result.overallScore,
      domainScoreOrNull(result.music),
      domainScoreOrNull(result.movie),
      domainScoreOrNull(result.book),
      JSON.stringify(result.sharedHighlights),
      JSON.stringify(result.divergenceHighlights),
    ],
  );
}

/**
 * Clears the viewer's passes so the queue can be worked through again.
 * Likes are kept - a pass is "not now", a like is a decision.
 */
export async function recycleDiscovery(db: Db, viewerId: string): Promise<number> {
  const { rows } = await db.query<{ count: string }>(
    `SELECT count(*)::text AS count FROM swipes
      WHERE actor_id = $1 AND direction = 'pass'`,
    [viewerId],
  );
  await db.query("DELETE FROM swipes WHERE actor_id = $1 AND direction = 'pass'", [viewerId]);
  return Number(rows[0]?.count ?? 0);
}

export interface PairCompatibility {
  user: PublicUser;
  overallScore: number;
  music: number | null;
  movie: number | null;
  book: number | null;
  sharedHighlights: Array<{ domain: string; label: string }>;
  divergenceHighlights: Array<{ domain: string; label: string; heldBy: string }>;
  tasteDna: TasteDna;
  yourTasteDna: TasteDna;
}

/**
 * Compatibility for one specific pair, computed directly rather than by
 * searching the discovery feed - the feed excludes anyone already swiped on,
 * so a match would otherwise report zero overlap with the person they matched.
 */
export async function getPairCompatibility(
  db: Db,
  viewerId: string,
  otherId: string,
): Promise<PairCompatibility | null> {
  const user = await readPublicUser(db, otherId);
  if (!user) return null;

  const popularity = await loadPopularityIndex(db);
  const viewerTaste = await loadTasteProfile(db, viewerId);
  const theirTaste = await loadTasteProfile(db, otherId);
  const result = computeCompatibility(viewerTaste, theirTaste, popularity);

  await cacheScore(db, viewerId, otherId, result);

  return {
    user,
    overallScore: result.overallScore,
    music: domainScoreOrNull(result.music),
    movie: domainScoreOrNull(result.movie),
    book: domainScoreOrNull(result.book),
    sharedHighlights: result.sharedHighlights.map((h) => ({ domain: h.domain, label: h.label })),
    divergenceHighlights: result.divergenceHighlights.map((d) => ({
      domain: d.domain,
      label: d.label,
      heldBy: d.heldBy,
    })),
    tasteDna: computeTasteDna(theirTaste, popularity),
    yourTasteDna: computeTasteDna(viewerTaste, popularity),
  };
}

export interface SwipeOutcome {
  matched: boolean;
  matchId: string | null;
  /** True when the like created a pending request rather than a connection. */
  requested: boolean;
}

/**
 * A like sends a connection REQUEST (proposal 4.1) rather than quietly creating
 * a match. If the other person had already requested you, your like accepts
 * theirs and you connect immediately — so the mutual-like gesture still works,
 * but nobody is connected without having opted in.
 */
export async function recordSwipe(
  db: Db,
  actorId: string,
  targetId: string,
  direction: 'like' | 'pass',
): Promise<SwipeOutcome> {
  if (actorId === targetId) {
    throw ApiError.badRequest('self_swipe', "You can't swipe on yourself.");
  }

  await db.query(
    `INSERT INTO swipes (id, actor_id, target_id, direction)
     VALUES ($1,$2,$3,$4)
     ON CONFLICT (actor_id, target_id) DO UPDATE SET direction = EXCLUDED.direction`,
    [newId(), actorId, targetId, direction],
  );

  if (direction === 'pass') return { matched: false, matchId: null, requested: false };

  const { requestConnection } = await import('./connections.js');
  const outcome = await requestConnection(db, actorId, targetId);

  switch (outcome.kind) {
    case 'connected':
      return { matched: true, matchId: outcome.matchId, requested: false };
    case 'requested':
    case 'already_pending':
      return { matched: false, matchId: null, requested: true };
  }
}

export interface MatchSummary {
  matchId: string;
  user: PublicUser;
  overallScore: number;
  lastMessage: string | null;
  lastMessageAt: string | null;
  unread: boolean;
}

export async function listMatches(db: Db, viewerId: string): Promise<MatchSummary[]> {
  const { rows } = await db.query<Record<string, any>>(
    `SELECT m.id AS match_id,
            CASE WHEN m.user_a_id = $1 THEN m.user_b_id ELSE m.user_a_id END AS other_id,
            c.overall_score,
            (SELECT content FROM messages ms WHERE ms.match_id = m.id
              ORDER BY sent_at DESC LIMIT 1) AS last_message,
            (SELECT sent_at FROM messages ms WHERE ms.match_id = m.id
              ORDER BY sent_at DESC LIMIT 1) AS last_message_at,
            EXISTS (SELECT 1 FROM messages ms WHERE ms.match_id = m.id
                      AND ms.sender_id <> $1 AND ms.read_at IS NULL) AS unread
       FROM matches m
       LEFT JOIN compatibility_scores c
              ON c.user_a_id = m.user_a_id AND c.user_b_id = m.user_b_id
      WHERE (m.user_a_id = $1 OR m.user_b_id = $1)
        AND m.status = 'active'
      ORDER BY COALESCE(
        (SELECT sent_at FROM messages ms WHERE ms.match_id = m.id ORDER BY sent_at DESC LIMIT 1),
        m.matched_at
      ) DESC`,
    [viewerId],
  );

  const out: MatchSummary[] = [];
  for (const row of rows) {
    const user = await readPublicUser(db, row.other_id);
    if (!user) continue;

    // A pair can match without ever having been scored (e.g. swiped by id), so
    // compute and cache on first read rather than reporting a misleading 0%.
    let score = row.overall_score;
    if (score === null || score === undefined) {
      score = (await getPairCompatibility(db, viewerId, row.other_id))?.overallScore ?? 0;
    }

    out.push({
      matchId: row.match_id,
      user,
      overallScore: score,
      lastMessage: row.last_message ?? null,
      lastMessageAt: row.last_message_at ? new Date(row.last_message_at).toISOString() : null,
      unread: Boolean(row.unread),
    });
  }
  return out;
}

async function assertMember(db: Db, matchId: string, userId: string): Promise<void> {
  const { rows } = await db.query<{ id: string }>(
    `SELECT id FROM matches
      WHERE id = $1 AND (user_a_id = $2 OR user_b_id = $2) AND status = 'active'`,
    [matchId, userId],
  );
  if (rows.length === 0) {
    throw ApiError.forbidden('not_your_match', 'That conversation is not available.');
  }
}

export interface Message {
  id: string;
  senderId: string;
  content: string;
  sentAt: string;
  mine: boolean;
}

export async function listMessages(
  db: Db,
  matchId: string,
  viewerId: string,
): Promise<Message[]> {
  await assertMember(db, matchId, viewerId);

  const { rows } = await db.query<Record<string, any>>(
    'SELECT id, sender_id, content, sent_at FROM messages WHERE match_id = $1 ORDER BY sent_at ASC',
    [matchId],
  );

  // Opening the thread marks the other side's messages read.
  await db.query(
    'UPDATE messages SET read_at = now() WHERE match_id = $1 AND sender_id <> $2 AND read_at IS NULL',
    [matchId, viewerId],
  );

  return rows.map((m) => ({
    id: m.id,
    senderId: m.sender_id,
    content: m.content,
    sentAt: new Date(m.sent_at).toISOString(),
    mine: m.sender_id === viewerId,
  }));
}

export async function sendMessage(
  db: Db,
  matchId: string,
  senderId: string,
  content: string,
): Promise<Message> {
  await assertMember(db, matchId, senderId);
  const trimmed = content.trim();
  if (trimmed.length === 0) {
    throw ApiError.badRequest('empty_message', 'Write something first.');
  }
  if (trimmed.length > 2000) {
    throw ApiError.badRequest('message_too_long', 'That message is too long.');
  }

  const id = newId();
  await db.query(
    'INSERT INTO messages (id, match_id, sender_id, content) VALUES ($1,$2,$3,$4)',
    [id, matchId, senderId, trimmed],
  );

  // A synthetic profile with auto_reply answers immediately (see autoReply.ts).
  const { maybeAutoReply } = await import('./autoReply.js');
  await maybeAutoReply(db, matchId, senderId);

  return { id, senderId, content: trimmed, sentAt: new Date().toISOString(), mine: true };
}

export async function unmatch(db: Db, matchId: string, viewerId: string): Promise<void> {
  await assertMember(db, matchId, viewerId);
  await db.query("UPDATE matches SET status = 'unmatched' WHERE id = $1", [matchId]);
}

export async function blockUser(db: Db, blockerId: string, blockedId: string): Promise<void> {
  await db.query(
    'INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
    [blockerId, blockedId],
  );
  const [userA, userB] = orderPair(blockerId, blockedId);
  await db.query(
    "UPDATE matches SET status = 'blocked' WHERE user_a_id = $1 AND user_b_id = $2",
    [userA, userB],
  );
}

export async function reportUser(
  db: Db,
  reporterId: string,
  reportedId: string,
  reason: string,
  detail?: string,
): Promise<void> {
  await db.query(
    'INSERT INTO reports (id, reporter_id, reported_id, reason, detail) VALUES ($1,$2,$3,$4,$5)',
    [newId(), reporterId, reportedId, reason, detail ?? null],
  );
}
