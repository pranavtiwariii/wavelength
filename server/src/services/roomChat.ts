import type { Db } from '../db/index.js';
import { ApiError } from '../lib/errors.js';
import { newId } from '../lib/ids.js';

/** Group chat inside a community. Membership is the gate. */
export interface RoomMessage {
  id: string;
  content: string;
  sentAt: string;
  mine: boolean;
  sender: { id: string; name: string | null; photoUrl: string | null };
}

async function assertMember(db: Db, communityId: string, userId: string): Promise<void> {
  const { rows } = await db.query<{ community_id: string }>(
    'SELECT community_id FROM community_members WHERE community_id = $1 AND user_id = $2',
    [communityId, userId],
  );
  if (rows.length === 0) {
    throw ApiError.forbidden('not_a_member', 'Join the room to see the conversation.');
  }
}

export async function listRoomMessages(
  db: Db,
  communityId: string,
  viewerId: string,
): Promise<RoomMessage[]> {
  await assertMember(db, communityId, viewerId);

  const { rows } = await db.query<Record<string, any>>(
    `SELECT m.id, m.content, m.sent_at, u.id AS sender_id, u.name, u.photo_url
       FROM room_messages m
       JOIN users u ON u.id = m.sender_id
      WHERE m.community_id = $1
      ORDER BY m.sent_at ASC
      LIMIT 200`,
    [communityId],
  );

  return rows.map((r) => ({
    id: r.id,
    content: r.content,
    sentAt: new Date(r.sent_at).toISOString(),
    mine: r.sender_id === viewerId,
    sender: { id: r.sender_id, name: r.name, photoUrl: r.photo_url },
  }));
}

export async function sendRoomMessage(
  db: Db,
  communityId: string,
  senderId: string,
  content: string,
): Promise<RoomMessage> {
  await assertMember(db, communityId, senderId);

  const trimmed = content.trim();
  if (trimmed.length === 0) throw ApiError.badRequest('empty_message', 'Write something first.');
  if (trimmed.length > 2000) {
    throw ApiError.badRequest('message_too_long', 'That message is too long.');
  }

  const id = newId();
  await db.query(
    'INSERT INTO room_messages (id, community_id, sender_id, content) VALUES ($1,$2,$3,$4)',
    [id, communityId, senderId, trimmed],
  );

  const { rows } = await db.query<Record<string, any>>(
    'SELECT name, photo_url FROM users WHERE id = $1',
    [senderId],
  );

  return {
    id,
    content: trimmed,
    sentAt: new Date().toISOString(),
    mine: true,
    sender: { id: senderId, name: rows[0]?.name ?? null, photoUrl: rows[0]?.photo_url ?? null },
  };
}
