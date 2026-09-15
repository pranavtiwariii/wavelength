import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createTestDb, type Db } from '../db/index.js';
import { runMigrations } from '../db/migrate.js';
import { newId } from '../lib/ids.js';
import {
  createCommunity,
  joinCommunity,
  leaveCommunity,
  listCommunities,
  listMembers,
  suggestCommunities,
} from './communities.js';
import { createDrop, listCommunityDrops, listFeed, react } from './drops.js';

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

async function giveMusic(userId: string, key: string, label: string, genres: string[]) {
  await db.query(
    `INSERT INTO music_profile (user_id, top_artists, source)
     VALUES ($1, $2::jsonb, 'test')
     ON CONFLICT (user_id) DO UPDATE SET top_artists = EXCLUDED.top_artists`,
    [
      userId,
      JSON.stringify([
        { key, label, addedAt: new Date().toISOString(), meta: { genres, creator: label } },
      ]),
    ],
  );
}

beforeEach(async () => {
  db = await createTestDb();
  await runMigrations(db);
});

afterAll(async () => {
  await db?.close();
});

describe('Content Drops (proposal 4.1)', () => {
  it('a drop appears in the feed with its author and domain', async () => {
    const user = await makeUser('Ada');
    await createDrop(db, user, {
      domain: 'music',
      itemKey: 'mb:1',
      itemLabel: 'Radiohead',
      caption: 'still the best',
    });

    const feed = await listFeed(db, user);
    expect(feed).toHaveLength(1);
    expect(feed[0]!.itemLabel).toBe('Radiohead');
    expect(feed[0]!.domain).toBe('music');
    expect(feed[0]!.author.name).toBe('Ada');
  });

  it('flags a drop the viewer also has in their own taste', async () => {
    const author = await makeUser('Ada');
    const viewer = await makeUser('Bo');
    await giveMusic(viewer, 'mb:1', 'Radiohead', ['alternative rock']);

    await createDrop(db, author, { domain: 'music', itemKey: 'mb:1', itemLabel: 'Radiohead' });
    await createDrop(db, author, { domain: 'music', itemKey: 'mb:2', itemLabel: 'Aphex Twin' });

    const feed = await listFeed(db, viewer);
    const shared = feed.find((d) => d.itemKey === 'mb:1');
    const notShared = feed.find((d) => d.itemKey === 'mb:2');

    expect(shared!.sharedWithMe).toBe(true);
    expect(notShared!.sharedWithMe).toBe(false);
  });

  it('counts likes and saves separately, and is idempotent', async () => {
    const author = await makeUser('Ada');
    const viewer = await makeUser('Bo');
    const drop = await createDrop(db, author, {
      domain: 'book',
      itemKey: 'ol:1',
      itemLabel: 'Piranesi',
    });

    await react(db, viewer, drop.id, 'like', true);
    await react(db, viewer, drop.id, 'like', true); // repeat must not double-count
    await react(db, viewer, drop.id, 'save', true);

    const [seen] = await listFeed(db, viewer);
    expect(seen!.likeCount).toBe(1);
    expect(seen!.saveCount).toBe(1);
    expect(seen!.likedByMe).toBe(true);
    expect(seen!.savedByMe).toBe(true);

    await react(db, viewer, drop.id, 'like', false);
    const [after] = await listFeed(db, viewer);
    expect(after!.likeCount).toBe(0);
    expect(after!.likedByMe).toBe(false);
  });

  it('refuses to post into a community you have not joined', async () => {
    const user = await makeUser('Ada');
    const communityId = await createCommunity(db, {
      slug: 'test-room',
      name: 'Test Room',
      tags: ['rock'],
    });

    await expect(
      createDrop(db, user, {
        domain: 'music',
        itemKey: 'mb:1',
        itemLabel: 'Radiohead',
        communityId,
      }),
    ).rejects.toThrow(/Join the community/);

    await joinCommunity(db, user, communityId);
    const drop = await createDrop(db, user, {
      domain: 'music',
      itemKey: 'mb:1',
      itemLabel: 'Radiohead',
      communityId,
    });
    expect(drop.community?.slug).toBe('test-room');
    await expect(listCommunityDrops(db, user, communityId)).resolves.toHaveLength(1);
  });

  it('hides drops from someone you blocked', async () => {
    const viewer = await makeUser('Ada');
    const blocked = await makeUser('Bo');
    await createDrop(db, blocked, { domain: 'music', itemKey: 'mb:1', itemLabel: 'Radiohead' });

    await db.query('INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1,$2)', [
      viewer,
      blocked,
    ]);

    await expect(listFeed(db, viewer)).resolves.toHaveLength(0);
  });
});

describe('Communities (proposal 4.1)', () => {
  it('suggests communities whose tags match the user\'s own taste', async () => {
    const user = await makeUser('Ada');
    await giveMusic(user, 'mb:1', 'Radiohead', ['alternative rock', 'art rock']);

    await createCommunity(db, {
      slug: 'rock-room',
      name: 'Rock Room',
      tags: ['alternative rock', 'art rock'],
    });
    await createCommunity(db, { slug: 'pop-room', name: 'Pop Room', tags: ['country pop'] });

    const suggestions = await suggestCommunities(db, user);
    expect(suggestions[0]!.slug).toBe('rock-room');
    expect(suggestions[0]!.matchedTags).toContain('alternative rock');
    expect(suggestions.map((s) => s.slug)).not.toContain('pop-room');
  });

  it('ranks a stronger tag overlap above a weaker one', async () => {
    const user = await makeUser('Ada');
    await giveMusic(user, 'mb:1', 'Radiohead', ['alternative rock', 'art rock']);

    await createCommunity(db, { slug: 'weak', name: 'Weak', tags: ['art rock'] });
    await createCommunity(db, {
      slug: 'strong',
      name: 'Strong',
      tags: ['alternative rock', 'art rock', 'radiohead'],
    });

    const suggestions = await suggestCommunities(db, user);
    expect(suggestions[0]!.slug).toBe('strong');
  });

  it('drops a community out of suggestions once joined', async () => {
    const user = await makeUser('Ada');
    await giveMusic(user, 'mb:1', 'Radiohead', ['alternative rock']);
    const id = await createCommunity(db, {
      slug: 'rock-room',
      name: 'Rock Room',
      tags: ['alternative rock'],
    });

    await joinCommunity(db, user, id);
    const suggestions = await suggestCommunities(db, user);
    expect(suggestions.map((s) => s.slug)).not.toContain('rock-room');
  });

  it('tracks membership both ways', async () => {
    const user = await makeUser('Ada');
    const id = await createCommunity(db, { slug: 'room', name: 'Room', tags: [] });

    await joinCommunity(db, user, id);
    await expect(listMembers(db, id)).resolves.toHaveLength(1);
    expect((await listCommunities(db, user))[0]!.joined).toBe(true);
    expect((await listCommunities(db, user))[0]!.memberCount).toBe(1);

    await leaveCommunity(db, user, id);
    await expect(listMembers(db, id)).resolves.toHaveLength(0);
    expect((await listCommunities(db, user))[0]!.joined).toBe(false);
  });

  it('falls back to popular rooms when the user has no taste yet', async () => {
    const user = await makeUser('Ada');
    await createCommunity(db, { slug: 'room', name: 'Room', tags: ['jazz'] });

    // No taste profile, so nothing can match - but the screen shouldn't be empty.
    const suggestions = await suggestCommunities(db, user);
    expect(suggestions).toHaveLength(1);
    expect(suggestions[0]!.matchedTags ?? []).toHaveLength(0);
  });
});
