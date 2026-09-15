import type { Db } from '../db/index.js';
import { ApiError } from '../lib/errors.js';
import { newId, orderPair } from '../lib/ids.js';

/**
 * Proposal 4.1: connections are opt-in and bidirectional — a request that the
 * other person accepts — rather than one-directional following. A conversation
 * only opens once both sides have agreed.
 *
 * Liking someone in Discovery sends a request. If they had already requested
 * you, your like accepts theirs, so the familiar mutual-like gesture still
 * produces an instant match without bypassing consent.
 */

export type ConnectionOutcome =
  | { kind: 'requested'; requestId: string }
  | { kind: 'connected'; matchId: string }
  | { kind: 'already_pending' };

export async function requestConnection(
  db: Db,
  requesterId: string,
  recipientId: string,
  message?: string,
): Promise<ConnectionOutcome> {
  if (requesterId === recipientId) {
    throw ApiError.badRequest('self_request', "You can't connect with yourself.");
  }

  // Did they already ask us? Then this is an acceptance.
  const { rows: incoming } = await db.query<{ id: string }>(
    `SELECT id FROM connection_requests
      WHERE requester_id = $1 AND recipient_id = $2 AND status = 'pending'`,
    [recipientId, requesterId],
  );
  if (incoming[0]) {
    const matchId = await acceptConnection(db, incoming[0].id, requesterId);
    return { kind: 'connected', matchId };
  }

  const { rows: existing } = await db.query<{ id: string; status: string }>(
    `SELECT id, status FROM connection_requests
      WHERE requester_id = $1 AND recipient_id = $2`,
    [requesterId, recipientId],
  );
  if (existing[0]?.status === 'pending') return { kind: 'already_pending' };

  const id = newId();
  if (existing[0]) {
    // Re-asking after a decline or withdrawal reopens the same row.
    await db.query(
      `UPDATE connection_requests
          SET status = 'pending', message = $2, created_at = now(), responded_at = NULL
        WHERE id = $1`,
      [existing[0].id, message ?? null],
    );
    return { kind: 'requested', requestId: existing[0].id };
  }

  await db.query(
    `INSERT INTO connection_requests (id, requester_id, recipient_id, message)
     VALUES ($1,$2,$3,$4)`,
    [id, requesterId, recipientId, message ?? null],
  );
  return { kind: 'requested', requestId: id };
}

/** Accepting creates the match, which is what unlocks chat. */
export async function acceptConnection(
  db: Db,
  requestId: string,
  actorId: string,
): Promise<string> {
  const { rows } = await db.query<{
    requester_id: string;
    recipient_id: string;
    status: string;
  }>('SELECT requester_id, recipient_id, status FROM connection_requests WHERE id = $1', [
    requestId,
  ]);

  const request = rows[0];
  if (!request) throw ApiError.notFound('request_not_found', 'That request no longer exists.');
  if (request.recipient_id !== actorId) {
    throw ApiError.forbidden('not_yours', 'That request was not sent to you.');
  }
  if (request.status !== 'pending') {
    throw ApiError.badRequest('already_answered', 'That request has already been answered.');
  }

  await db.query(
    "UPDATE connection_requests SET status = 'accepted', responded_at = now() WHERE id = $1",
    [requestId],
  );

  const [userA, userB] = orderPair(request.requester_id, request.recipient_id);
  const { rows: existing } = await db.query<{ id: string }>(
    'SELECT id FROM matches WHERE user_a_id = $1 AND user_b_id = $2',
    [userA, userB],
  );
  if (existing[0]) {
    await db.query("UPDATE matches SET status = 'active' WHERE id = $1", [existing[0].id]);
    return existing[0].id;
  }

  const matchId = newId();
  await db.query('INSERT INTO matches (id, user_a_id, user_b_id) VALUES ($1,$2,$3)', [
    matchId,
    userA,
    userB,
  ]);
  return matchId;
}

export async function declineConnection(
  db: Db,
  requestId: string,
  actorId: string,
): Promise<void> {
  const { rows } = await db.query<{ recipient_id: string; status: string }>(
    'SELECT recipient_id, status FROM connection_requests WHERE id = $1',
    [requestId],
  );
  const request = rows[0];
  if (!request) throw ApiError.notFound('request_not_found', 'That request no longer exists.');
  if (request.recipient_id !== actorId) {
    throw ApiError.forbidden('not_yours', 'That request was not sent to you.');
  }
  await db.query(
    "UPDATE connection_requests SET status = 'declined', responded_at = now() WHERE id = $1",
    [requestId],
  );
}

export interface PendingRequest {
  id: string;
  user: {
    id: string;
    name: string | null;
    age: number | null;
    city: string | null;
    bio: string | null;
    photoUrl: string | null;
  };
  message: string | null;
  createdAt: string;
  overallScore: number;
}

/** Requests waiting on the signed-in user, newest first. */
export async function listIncomingRequests(
  db: Db,
  userId: string,
): Promise<PendingRequest[]> {
  const { rows } = await db.query<Record<string, any>>(
    `SELECT r.id, r.message, r.created_at,
            u.id AS user_id, u.name, u.age, u.city, u.bio, u.photo_url,
            c.overall_score
       FROM connection_requests r
       JOIN users u ON u.id = r.requester_id
       LEFT JOIN compatibility_scores c
              ON c.user_a_id = LEAST(r.requester_id, r.recipient_id)
             AND c.user_b_id = GREATEST(r.requester_id, r.recipient_id)
      WHERE r.recipient_id = $1 AND r.status = 'pending'
      ORDER BY r.created_at DESC`,
    [userId],
  );

  return rows.map((r) => ({
    id: r.id,
    user: {
      id: r.user_id,
      name: r.name,
      age: r.age,
      city: r.city,
      bio: r.bio,
      photoUrl: r.photo_url,
    },
    message: r.message,
    createdAt: new Date(r.created_at).toISOString(),
    overallScore: r.overall_score ?? 0,
  }));
}

export async function countIncomingRequests(db: Db, userId: string): Promise<number> {
  const { rows } = await db.query<{ count: string }>(
    `SELECT count(*)::text AS count FROM connection_requests
      WHERE recipient_id = $1 AND status = 'pending'`,
    [userId],
  );
  return Number(rows[0]?.count ?? 0);
}

/** True when the two users are connected — the gate for private content. */
export async function areConnected(db: Db, a: string, b: string): Promise<boolean> {
  const [userA, userB] = orderPair(a, b);
  const { rows } = await db.query<{ id: string }>(
    "SELECT id FROM matches WHERE user_a_id = $1 AND user_b_id = $2 AND status = 'active'",
    [userA, userB],
  );
  return rows.length > 0;
}
