import type { Db } from '../db/index.js';
import { newId } from '../lib/ids.js';

/**
 * Proposal 5.2: the notification service. In-app only — there is no push
 * transport wired up, so these are generated at the moment the event happens
 * and read from the inbox.
 *
 * Every emit is best-effort: a notification is a side effect of something that
 * already succeeded, so failing to record one must never fail the action that
 * caused it.
 */
export type NotificationKind =
  | 'connection_request'
  | 'connection_accepted'
  | 'new_match'
  | 'message'
  | 'drop_like'
  | 'room_message';

export interface Notification {
  id: string;
  kind: NotificationKind;
  body: string;
  target: string | null;
  readAt: string | null;
  createdAt: string;
  actor: { id: string; name: string | null; photoUrl: string | null } | null;
}

export async function emit(
  db: Db,
  params: {
    userId: string;
    kind: NotificationKind;
    body: string;
    actorId?: string;
    target?: string;
  },
): Promise<void> {
  // Never notify someone about their own action.
  if (params.actorId && params.actorId === params.userId) return;

  try {
    await db.query(
      `INSERT INTO notifications (id, user_id, kind, actor_id, target, body)
       VALUES ($1,$2,$3,$4,$5,$6)`,
      [
        newId(),
        params.userId,
        params.kind,
        params.actorId ?? null,
        params.target ?? null,
        params.body,
      ],
    );
  } catch {
    // Swallow: the underlying action already happened.
  }
}

export async function listNotifications(
  db: Db,
  userId: string,
  limit = 50,
): Promise<Notification[]> {
  const { rows } = await db.query<Record<string, any>>(
    `SELECT n.id, n.kind, n.body, n.target, n.read_at, n.created_at,
            a.id AS actor_id, a.name AS actor_name, a.photo_url AS actor_photo
       FROM notifications n
       LEFT JOIN users a ON a.id = n.actor_id
      WHERE n.user_id = $1
      ORDER BY n.created_at DESC
      LIMIT $2`,
    [userId, limit],
  );

  return rows.map((r) => ({
    id: r.id,
    kind: r.kind,
    body: r.body,
    target: r.target,
    readAt: r.read_at ? new Date(r.read_at).toISOString() : null,
    createdAt: new Date(r.created_at).toISOString(),
    actor: r.actor_id
      ? { id: r.actor_id, name: r.actor_name, photoUrl: r.actor_photo }
      : null,
  }));
}

export async function countUnread(db: Db, userId: string): Promise<number> {
  const { rows } = await db.query<{ count: string }>(
    'SELECT count(*)::text AS count FROM notifications WHERE user_id = $1 AND read_at IS NULL',
    [userId],
  );
  return Number(rows[0]?.count ?? 0);
}

export async function markAllRead(db: Db, userId: string): Promise<void> {
  await db.query(
    'UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL',
    [userId],
  );
}

/** Display name for an actor, for notification copy. */
export async function nameOf(db: Db, userId: string): Promise<string> {
  const { rows } = await db.query<{ name: string | null }>(
    'SELECT name FROM users WHERE id = $1',
    [userId],
  );
  return rows[0]?.name ?? 'Someone';
}
