import type { Db } from '../db/index.js';
import { newId } from '../lib/ids.js';
import { getPairCompatibility } from './social.js';

/**
 * Some synthetic profiles answer messages. This exists so the full loop —
 * match, open the thread, say something, get a reply — can be demonstrated
 * without a second person on a second device.
 *
 * Replies are drawn from the pair's ACTUAL shared and divergent taste, so the
 * conversation is about the same things the match screen just claimed.
 * Nothing here pretends to be a person: `is_synthetic` is set on the row and
 * the client labels these profiles as demo accounts.
 */
export async function maybeAutoReply(
  db: Db,
  matchId: string,
  senderId: string,
): Promise<void> {
  const { rows } = await db.query<{ other_id: string; auto_reply: boolean; name: string | null }>(
    `SELECT CASE WHEN m.user_a_id = $2 THEN m.user_b_id ELSE m.user_a_id END AS other_id,
            u.auto_reply, u.name
       FROM matches m
       JOIN users u
         ON u.id = CASE WHEN m.user_a_id = $2 THEN m.user_b_id ELSE m.user_a_id END
      WHERE m.id = $1`,
    [matchId, senderId],
  );

  const other = rows[0];
  if (!other?.auto_reply) return;

  const reply = await composeReply(db, other.other_id, senderId);
  await db.query(
    'INSERT INTO messages (id, match_id, sender_id, content) VALUES ($1,$2,$3,$4)',
    [newId(), matchId, other.other_id, reply],
  );
}

async function composeReply(db: Db, botId: string, humanId: string): Promise<string> {
  const pair = await getPairCompatibility(db, botId, humanId);

  const shared = pair?.sharedHighlights ?? [];
  const mine = (pair?.divergenceHighlights ?? []).filter((d) => d.heldBy === botId);

  const options: string[] = [];

  if (shared.length > 0) {
    options.push(`Ok ${shared[0]!.label} is a real answer. What got you into it?`);
  }
  if (shared.length > 1) {
    options.push(
      `${shared[0]!.label} and ${shared[1]!.label} in the same profile is a specific kind of person. I respect it.`,
    );
  }
  if (mine.length > 0) {
    options.push(`I'll trade you — give ${mine[0]!.label} a proper go and I'll report back on yours.`);
  }
  options.push("Good pick. What else should I be listening to this week?");

  // Vary the opener so two demos in a row don't read identically.
  return options[Math.floor(Math.random() * options.length)]!;
}
