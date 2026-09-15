import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createTestDb, type Db } from '../db/index.js';
import { runMigrations } from '../db/migrate.js';
import { newId } from '../lib/ids.js';
import {
  acceptConnection,
  areConnected,
  countIncomingRequests,
  declineConnection,
  listIncomingRequests,
  requestConnection,
} from './connections.js';
import { listMessages, recordSwipe, sendMessage } from './social.js';

let db: Db;

async function makeUser(name: string): Promise<string> {
  const id = newId();
  await db.query(
    `INSERT INTO users (id, email, name, age, onboarding_stage, taste_profile_completeness)
     VALUES ($1,$2,$3,28,'complete',50)`,
    [id, `${name}-${id.slice(0, 8)}@test.local`, name],
  );
  return id;
}

beforeEach(async () => {
  db = await createTestDb();
  await runMigrations(db);
});

afterAll(async () => {
  await db?.close();
});

describe('connections are opt-in (proposal 4.1)', () => {
  it('a like creates a pending request, not a connection', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');

    const outcome = await recordSwipe(db, a, b, 'like');

    expect(outcome.requested).toBe(true);
    expect(outcome.matched).toBe(false);
    expect(outcome.matchId).toBeNull();
    await expect(areConnected(db, a, b)).resolves.toBe(false);
  });

  it('shows the request in the recipient inbox, not the sender', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);

    const inbox = await listIncomingRequests(db, b);
    expect(inbox).toHaveLength(1);
    expect(inbox[0]!.user.id).toBe(a);
    await expect(listIncomingRequests(db, a)).resolves.toHaveLength(0);
  });

  it('accepting connects the pair and unlocks the conversation', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);

    const [request] = await listIncomingRequests(db, b);
    const matchId = await acceptConnection(db, request!.id, b);

    await expect(areConnected(db, a, b)).resolves.toBe(true);
    await sendMessage(db, matchId, a, 'hello');
    await expect(listMessages(db, matchId, b)).resolves.toHaveLength(1);
  });

  it('declining leaves them unconnected', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);

    const [request] = await listIncomingRequests(db, b);
    await declineConnection(db, request!.id, b);

    await expect(areConnected(db, a, b)).resolves.toBe(false);
    await expect(countIncomingRequests(db, b)).resolves.toBe(0);
  });

  it('a mutual like connects immediately - the second like accepts the first', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');

    await recordSwipe(db, a, b, 'like');
    const second = await recordSwipe(db, b, a, 'like');

    expect(second.matched).toBe(true);
    expect(second.matchId).not.toBeNull();
    await expect(areConnected(db, a, b)).resolves.toBe(true);
  });

  it('only the recipient can answer a request', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    const c = await makeUser('Cy');
    await requestConnection(db, a, b);
    const [request] = await listIncomingRequests(db, b);

    await expect(acceptConnection(db, request!.id, c)).rejects.toThrow(/not sent to you/);
    await expect(acceptConnection(db, request!.id, a)).rejects.toThrow(/not sent to you/);
  });

  it('refuses to answer the same request twice', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);
    const [request] = await listIncomingRequests(db, b);

    await acceptConnection(db, request!.id, b);
    await expect(acceptConnection(db, request!.id, b)).rejects.toThrow(/already been answered/);
  });

  it('a repeated like does not stack duplicate requests', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');

    await requestConnection(db, a, b);
    const again = await requestConnection(db, a, b);

    expect(again.kind).toBe('already_pending');
    await expect(countIncomingRequests(db, b)).resolves.toBe(1);
  });

  it('a pass creates no request at all', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');

    const outcome = await recordSwipe(db, a, b, 'pass');

    expect(outcome.requested).toBe(false);
    await expect(countIncomingRequests(db, b)).resolves.toBe(0);
  });

  it('chat stays locked until a connection exists', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);

    // No match row exists yet, so there is nothing to post into.
    await expect(sendMessage(db, newId(), a, 'hi')).rejects.toThrow(/not available/);
  });

  it('re-asking after a decline reopens the request', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);
    const [first] = await listIncomingRequests(db, b);
    await declineConnection(db, first!.id, b);

    await requestConnection(db, a, b);
    await expect(countIncomingRequests(db, b)).resolves.toBe(1);
  });
});
