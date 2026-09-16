import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createTestDb, type Db } from '../db/index.js';
import { runMigrations } from '../db/migrate.js';
import { newId } from '../lib/ids.js';
import {
  acceptConnection,
  declineConnection,
  listIncomingRequests,
  requestConnection,
} from './connections.js';
import { countUnread, listNotifications, markAllRead } from './notifications.js';
import { createDrop, react } from './drops.js';
import { sendMessage } from './social.js';

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

describe('notification service (proposal 5.2)', () => {
  it('notifies the recipient of a connection request, and only them', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');

    await requestConnection(db, a, b);

    const theirs = await listNotifications(db, b);
    expect(theirs).toHaveLength(1);
    expect(theirs[0]!.kind).toBe('connection_request');
    expect(theirs[0]!.body).toContain('Ada');
    expect(theirs[0]!.target).toBe('/requests');
    await expect(listNotifications(db, a)).resolves.toHaveLength(0);
  });

  it('tells the requester when their request is accepted', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);
    const [request] = await listIncomingRequests(db, b);

    await acceptConnection(db, request!.id, b);

    const theirs = await listNotifications(db, a);
    expect(theirs.map((n) => n.kind)).toContain('connection_accepted');
    expect(theirs.find((n) => n.kind === 'connection_accepted')!.target).toMatch(/^\/chat\//);
  });

  it('says nothing when a request is declined', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);
    const [request] = await listIncomingRequests(db, b);

    await declineConnection(db, request!.id, b);

    // A decline is private - the requester is not told they were rejected.
    await expect(listNotifications(db, a)).resolves.toHaveLength(0);
  });

  it('notifies on a new message, but never the sender', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);
    const [request] = await listIncomingRequests(db, b);
    const matchId = await acceptConnection(db, request!.id, b);

    await markAllRead(db, a);
    await markAllRead(db, b);
    await sendMessage(db, matchId, a, 'hello there');

    const theirs = await listNotifications(db, b);
    expect(theirs[0]!.kind).toBe('message');
    expect(theirs[0]!.body).toContain('hello there');
    await expect(countUnread(db, a)).resolves.toBe(0);
  });

  it('notifies a drop author on a like but not on a save', async () => {
    const author = await makeUser('Ada');
    const reader = await makeUser('Bo');
    const drop = await createDrop(db, author, {
      domain: 'music',
      itemKey: 'mb:1',
      itemLabel: 'Radiohead',
    });

    await react(db, reader, drop.id, 'save', true);
    await expect(listNotifications(db, author)).resolves.toHaveLength(0);

    await react(db, reader, drop.id, 'like', true);
    const theirs = await listNotifications(db, author);
    expect(theirs).toHaveLength(1);
    expect(theirs[0]!.body).toContain('Radiohead');
  });

  it('never notifies someone about their own action', async () => {
    const author = await makeUser('Ada');
    const drop = await createDrop(db, author, {
      domain: 'music',
      itemKey: 'mb:1',
      itemLabel: 'Radiohead',
    });

    await react(db, author, drop.id, 'like', true);

    await expect(listNotifications(db, author)).resolves.toHaveLength(0);
  });

  it('counts unread and clears it on read', async () => {
    const a = await makeUser('Ada');
    const b = await makeUser('Bo');
    await requestConnection(db, a, b);

    await expect(countUnread(db, b)).resolves.toBe(1);
    await markAllRead(db, b);
    await expect(countUnread(db, b)).resolves.toBe(0);

    // The notification itself survives - only its unread state changes.
    await expect(listNotifications(db, b)).resolves.toHaveLength(1);
  });
});
