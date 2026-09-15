import type { Db } from '../db/index.js';
import { newId, orderPair } from '../lib/ids.js';
import { avatarFor } from './avatars.js';
import { joinCommunity, suggestCommunities } from './communities.js';
import { createDrop } from './drops.js';
import type { Domain } from './integrations/index.js';
import { computeCompleteness } from './taste.js';

/**
 * Builds a populated world around a brand-new user.
 *
 * Without this, a first-run account sees an empty Discover at 0% for everyone,
 * because compatibility needs BOTH sides to have taste. Rather than hoping the
 * seeded cohort happens to overlap, this generates people whose favourites are
 * drawn from the user's own — at graded overlap, so the scores span a realistic
 * range instead of all being high or all being zero.
 *
 * Everything it creates is flagged `is_synthetic`, carries no credentials, and
 * is generated once per user.
 */

const FIRST_NAMES = [
  'Aanya', 'Kabir', 'Riya', 'Vivaan', 'Meher', 'Arnav', 'Saanvi', 'Reyansh',
  'Diya', 'Aarav', 'Ira', 'Kiaan', 'Myra', 'Vihaan', 'Anika', 'Rudra',
  'Naina', 'Shaurya', 'Tara', 'Dhruv', 'Kyra', 'Advait', 'Sara', 'Neel',
];

const CITIES = ['Brooklyn', 'Manhattan', 'Queens', 'Jersey City', 'Hoboken'];

const BIOS = [
  'Will send you a 40-track playlist unprompted.',
  'Letterboxd diary is longer than my CV.',
  'Three books in progress, none finished.',
  'I peaked emotionally during a film you have not seen.',
  'Ask me about the bridge. Any bridge.',
  'Aggressively normal taste, aggressively defended.',
  'Currently ruining a perfectly good album by overplaying it.',
  'I will make you watch subtitles and you will thank me.',
  'Everything I like was recommended by someone cooler.',
  'Reading the sequel before finishing the first one.',
];

const OPENERS = [
  'Ok your taste is suspiciously good.',
  'We overlap way too much for strangers.',
  'Genuinely did not expect to see that in someone else’s profile.',
  'Right, we need to talk about this.',
];

const ROOM_LINES = [
  'Ok who else is still not over that ending.',
  'Genuinely the best thing I’ve heard all month.',
  'I have a whole argument prepared about this actually.',
  'Unpopular opinion: the second half is better.',
  'Someone give me something new, I’ve worn this one out.',
  'Bold of you all to assume I have a defensible reason.',
  'Three people recommended this to me and they were right.',
  'Started it last night, did not sleep.',
  'The production on this is absurd.',
  'Finally finished it. I need a minute.',
  'Does anyone else think this is wildly overrated?',
  'Give me one recommendation and I’ll give you three.',
];

interface StoredItem {
  key: string;
  label: string;
  subtitle?: string;
  meta?: { genres?: string[]; year?: number; creator?: string };
  addedAt: string;
}

const DOMAIN_SOURCE: Record<Domain, { table: string; column: string }> = {
  music: { table: 'music_profile', column: 'top_artists' },
  movie: { table: 'movie_profile', column: 'favorite_films' },
  book: { table: 'book_profile', column: 'favorite_books' },
};

const DOMAINS: readonly Domain[] = ['music', 'movie', 'book'] as const;

function parse(raw: unknown): StoredItem[] {
  if (!raw) return [];
  const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
  return Array.isArray(parsed) ? (parsed as StoredItem[]) : [];
}

async function readItems(db: Db, userId: string, domain: Domain): Promise<StoredItem[]> {
  const { table, column } = DOMAIN_SOURCE[domain];
  const { rows } = await db.query<Record<string, unknown>>(
    `SELECT ${column} AS items FROM ${table} WHERE user_id = $1`,
    [userId],
  );
  return parse(rows[0]?.items);
}

/** Every distinct item in the pool, so generated people have somewhere to differ. */
async function poolItems(db: Db, domain: Domain): Promise<StoredItem[]> {
  const { table, column } = DOMAIN_SOURCE[domain];
  const { rows } = await db.query<Record<string, unknown>>(`SELECT ${column} AS items FROM ${table}`);

  const byKey = new Map<string, StoredItem>();
  for (const row of rows) {
    for (const item of parse(row.items)) {
      if (item?.key) byKey.set(item.key, item);
    }
  }
  return [...byKey.values()];
}

function sample<T>(list: T[], count: number): T[] {
  const copy = [...list];
  const out: T[] = [];
  while (out.length < count && copy.length > 0) {
    out.push(copy.splice(Math.floor(Math.random() * copy.length), 1)[0]!);
  }
  return out;
}

function pick<T>(list: T[]): T {
  return list[Math.floor(Math.random() * list.length)]!;
}

export interface BootstrapResult {
  created: number;
  matches: number;
  requests: number;
}

/**
 * @param extra when true, generates another batch even if the pool was already
 *   bootstrapped, and skips seeding matches/requests - used by "expand pool".
 */
export async function bootstrapPool(
  db: Db,
  userId: string,
  extra = false,
): Promise<BootstrapResult> {
  const { rows: userRows } = await db.query<{
    gender: string | null;
    seeking: string | null;
    intent: string | null;
    pool_bootstrapped: boolean;
  }>('SELECT gender, seeking, intent, pool_bootstrapped FROM users WHERE id = $1', [userId]);

  const me = userRows[0];
  if (!me) return { created: 0, matches: 0, requests: 0 };
  if (me.pool_bootstrapped && !extra) return { created: 0, matches: 0, requests: 0 };

  const mine: Record<Domain, StoredItem[]> = {
    music: await readItems(db, userId, 'music'),
    movie: await readItems(db, userId, 'movie'),
    book: await readItems(db, userId, 'book'),
  };
  const pool: Record<Domain, StoredItem[]> = {
    music: await poolItems(db, 'music'),
    movie: await poolItems(db, 'movie'),
    book: await poolItems(db, 'book'),
  };

  // Overlap tiers: how much of this person's taste comes from the user's own.
  // A spread beats a uniform blur - some obvious matches, some near-misses.
  const tiers = (
    extra
      ? [...Array(3).fill(0.85), ...Array(4).fill(0.6), ...Array(3).fill(0.35)]
      : [
          ...Array(4).fill(0.9),
          ...Array(5).fill(0.65),
          ...Array(6).fill(0.4),
          ...Array(5).fill(0.15),
        ]
  ) as number[];

  // If the user is dating and has a preference, most generated people should
  // be someone they'd actually be shown.
  const wanted =
    me.intent === 'dating' && me.seeking === 'men'
      ? 'man'
      : me.intent === 'dating' && me.seeking === 'women'
        ? 'woman'
        : null;

  const names = sample(FIRST_NAMES, tiers.length);
  const created: string[] = [];

  for (let i = 0; i < tiers.length; i++) {
    const overlap = tiers[i]!;
    const id = newId();
    const name = names[i] ?? `Person ${i + 1}`;
    const gender =
      wanted ?? (['woman', 'man', 'nonbinary'] as const)[Math.floor(Math.random() * 3)]!;

    // Build the taste in memory first: the profile rows have a foreign key to
    // users, so the person has to exist before their favourites can.
    const counts: Record<Domain, number> = { music: 0, movie: 0, book: 0 };
    const chosen: Partial<Record<Domain, StoredItem[]>> = {};

    for (const domain of DOMAINS) {
      const source = mine[domain];
      if (source.length === 0 && pool[domain].length === 0) continue;

      const target = Math.min(5, Math.max(3, source.length + 1));
      const shared = sample(source, Math.round(target * overlap));
      const sharedKeys = new Set(shared.map((s) => s.key));
      const different = sample(
        pool[domain].filter((p) => !sharedKeys.has(p.key)),
        target - shared.length,
      );

      const items = [...shared, ...different].map((item) => ({
        ...item,
        addedAt: new Date().toISOString(),
      }));
      if (items.length === 0) continue;

      counts[domain] = items.length;
      chosen[domain] = items;
    }

    await db.query(
      `INSERT INTO users (id, name, age, gender, intent, seeking, city, bio, photo_url,
                          interested_in, onboarding_stage, taste_profile_completeness,
                          is_synthetic, auto_reply, pool_bootstrapped)
       VALUES ($1,$2,$3,$4,$5,'everyone',$6,$7,$8,'["everyone"]'::jsonb,'complete',
               $9,TRUE,TRUE,TRUE)`,
      [
        id,
        name,
        22 + Math.floor(Math.random() * 12),
        gender,
        me.intent ?? 'both',
        pick(CITIES),
        pick(BIOS),
        avatarFor(id, name),
        computeCompleteness(counts),
      ],
    );

    for (const domain of DOMAINS) {
      const items = chosen[domain];
      if (!items) continue;

      const { table, column } = DOMAIN_SOURCE[domain];
      await db.query(
        `INSERT INTO ${table} (user_id, ${column}, source, last_synced_at)
         VALUES ($1, $2::jsonb, 'generated', now())
         ON CONFLICT (user_id) DO UPDATE SET ${column} = EXCLUDED.${column}`,
        [id, JSON.stringify(items)],
      );

      for (const item of items) {
        await db.query(
          `INSERT INTO item_popularity (domain, item_key, user_count)
           VALUES ($1,$2,1)
           ON CONFLICT (domain, item_key) DO UPDATE
             SET user_count = item_popularity.user_count + 1, updated_at = now()`,
          [domain, item.key],
        );
      }
    }

    await db.query('INSERT INTO privacy_settings (user_id) VALUES ($1)', [id]);
    created.push(id);
  }

  // The three closest become live conversations, the next three arrive as
  // pending requests, so Matches and Requests both have something in them.
  // Expanding only adds people to swipe on - it doesn't fabricate more
  // conversations on top of the ones already there.
  const matchIds = extra ? [] : created.slice(0, 3);
  const requestIds = extra ? [] : created.slice(3, 6);

  for (const otherId of matchIds) {
    const [a, b] = orderPair(userId, otherId);
    const matchId = newId();
    await db.query(
      `INSERT INTO matches (id, user_a_id, user_b_id) VALUES ($1,$2,$3)
       ON CONFLICT (user_a_id, user_b_id) DO NOTHING`,
      [matchId, a, b],
    );
    await db.query(
      `INSERT INTO connection_requests (id, requester_id, recipient_id, status, responded_at)
       VALUES ($1,$2,$3,'accepted', now())
       ON CONFLICT (requester_id, recipient_id) DO NOTHING`,
      [newId(), otherId, userId],
    );
    // Both directions, so neither shows up in Discover again.
    for (const [actor, target] of [
      [userId, otherId],
      [otherId, userId],
    ]) {
      await db.query(
        `INSERT INTO swipes (id, actor_id, target_id, direction) VALUES ($1,$2,$3,'like')
         ON CONFLICT (actor_id, target_id) DO NOTHING`,
        [newId(), actor, target],
      );
    }
  }

  // Give the first match a short exchange already in progress.
  const firstMatch = matchIds[0];
  if (firstMatch) {
    const { rows } = await db.query<{ id: string }>(
      'SELECT id FROM matches WHERE user_a_id = $1 AND user_b_id = $2',
      orderPair(userId, firstMatch),
    );
    const matchId = rows[0]?.id;
    if (matchId) {
      await db.query(
        'INSERT INTO messages (id, match_id, sender_id, content, sent_at) VALUES ($1,$2,$3,$4, now() - interval \'2 hours\')',
        [newId(), matchId, firstMatch, pick(OPENERS)],
      );
    }
  }

  for (const otherId of requestIds) {
    await db.query(
      `INSERT INTO connection_requests (id, requester_id, recipient_id, status)
       VALUES ($1,$2,$3,'pending')
       ON CONFLICT (requester_id, recipient_id) DO NOTHING`,
      [newId(), otherId, userId],
    );
    await db.query(
      `INSERT INTO swipes (id, actor_id, target_id, direction) VALUES ($1,$2,$3,'like')
       ON CONFLICT (actor_id, target_id) DO NOTHING`,
      [newId(), otherId, userId],
    );
  }

  // Put the generated people into rooms that match them, and have them talk.
  // Lines are handed out by index rather than at random - picking randomly
  // from a short list produced a room where six people said the same thing.
  let lineCursor = Math.floor(Math.random() * ROOM_LINES.length);
  for (const otherId of created.slice(0, 12)) {
    const suggestions = await suggestCommunities(db, otherId, 2);
    for (const community of suggestions) {
      await joinCommunity(db, otherId, community.id);
    }

    const home = suggestions[0];
    if (!home) continue;

    const items = await readItems(db, otherId, 'music');
    const item = items[0];
    if (item && Math.random() > 0.45) {
      await createDrop(db, otherId, {
        domain: 'music',
        itemKey: item.key,
        itemLabel: item.label,
        itemSubtitle: item.subtitle,
        caption: pick(BIOS),
        communityId: home.id,
      });
    }

    if (Math.random() > 0.35) {
      await db.query(
        `INSERT INTO room_messages (id, community_id, sender_id, content, sent_at)
         VALUES ($1,$2,$3,$4, now() - (random() * interval '20 hours'))`,
        [newId(), home.id, otherId, ROOM_LINES[lineCursor++ % ROOM_LINES.length]!],
      );
    }
  }

  await db.query('UPDATE users SET pool_bootstrapped = TRUE WHERE id = $1', [userId]);

  return { created: created.length, matches: matchIds.length, requests: requestIds.length };
}
