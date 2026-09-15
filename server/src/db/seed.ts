import { avatarFor } from '../services/avatars.js';
import { providers, type Domain } from '../services/integrations/index.js';
import { closeDb, getDb, type Db } from './index.js';
import { runMigrations } from './migrate.js';
import { newId } from '../lib/ids.js';

/**
 * Seeds demo people so Discovery has something to show in development.
 * Taste is hand-picked to produce a spread of compatibility scores rather than
 * a uniform blur - some near-twins, some deliberate opposites.
 *
 * Idempotent: seeded accounts use @seed.wavelength.test and are replaced.
 */

interface SeedItem {
  key: string;
  label: string;
  subtitle?: string;
  genres?: string[];
  year?: number;
  creator?: string;
}

interface SeedPerson {
  name: string;
  age: number;
  city: string;
  bio: string;
  gender: 'woman' | 'man' | 'nonbinary';
  intent: 'dating' | 'friends' | 'both';
  /** One person per demo answers messages, so the loop is showable solo. */
  autoReply?: boolean;
  music: SeedItem[];
  movie: SeedItem[];
  book: SeedItem[];
}

/**
 * Seed favourites are resolved through the SAME providers the app uses, so a
 * seeded person and a real user who both add "Radiohead" end up with the
 * identical item key and genuinely overlap. Hand-written ids would look right
 * in the database and silently never match anything.
 */
async function resolve(
  domain: Domain,
  query: string,
  fallbackMeta: { genres?: string[]; year?: number; creator?: string },
): Promise<SeedItem> {
  const cacheKey = `${domain}:${query.toLowerCase()}`;
  const cached = resolved.get(cacheKey);
  if (cached) return cached;

  let item: SeedItem;
  try {
    const results = await providers[domain].search(query);
    // Prefer an exact title match; providers rank loosely.
    const hit =
      results.find((r) => r.label.toLowerCase() === query.toLowerCase()) ?? results[0];
    if (!hit) throw new Error('no results');
    item = {
      key: hit.key,
      label: hit.label,
      ...(hit.subtitle ? { subtitle: hit.subtitle } : {}),
      genres: hit.meta?.genres ?? fallbackMeta.genres,
      year: hit.meta?.year ?? fallbackMeta.year,
      creator: hit.meta?.creator ?? fallbackMeta.creator,
    };
  } catch {
    // Offline or provider down: fall back to a deterministic local key so
    // seeding still works, and seeded people still overlap with each other.
    item = {
      key: `seed:${domain}:${query.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
      label: query,
      ...fallbackMeta,
    };
  }

  resolved.set(cacheKey, item);
  // Be polite to MusicBrainz (~1 request/second) and Wikidata.
  await new Promise((r) => setTimeout(r, 1100));
  return item;
}

const resolved = new Map<string, SeedItem>();

async function buildPeople(): Promise<SeedPerson[]> {
  // A shared vocabulary, so overlaps between seeded people are real.
  const radiohead = await resolve('music', 'Radiohead', { genres: ['alternative rock', 'art rock'], creator: 'Radiohead' });
  const phoebe = await resolve('music', 'Phoebe Bridgers', { genres: ['indie folk', 'sadcore'], creator: 'Phoebe Bridgers' });
  const aphex = await resolve('music', 'Aphex Twin', { genres: ['idm', 'experimental electronic'], creator: 'Aphex Twin' });
  const beyonce = await resolve('music', 'Beyoncé', { genres: ['pop', 'r&b'], creator: 'Beyoncé' });
  const sufjan = await resolve('music', 'Sufjan Stevens', { genres: ['indie folk', 'chamber pop'], creator: 'Sufjan Stevens' });
  const kendrick = await resolve('music', 'Kendrick Lamar', { genres: ['hip hop'], creator: 'Kendrick Lamar' });
  const fka = await resolve('music', 'FKA twigs', { genres: ['art pop', 'experimental'], creator: 'FKA twigs' });
  const taylor = await resolve('music', 'Taylor Swift', { genres: ['pop', 'country pop'], creator: 'Taylor Swift' });

  const moodForLove = await resolve('movie', 'In the Mood for Love', { genres: ['romance', 'art house', 'drama'], year: 2000, creator: 'Wong Kar-wai' });
  const parasite = await resolve('movie', 'Parasite', { genres: ['thriller', 'black comedy'], year: 2019, creator: 'Bong Joon-ho' });
  const eeaao = await resolve('movie', 'Everything Everywhere All at Once', { genres: ['science fiction', 'comedy'], year: 2022, creator: 'Daniel Kwan' });
  const lostTrans = await resolve('movie', 'Lost in Translation', { genres: ['drama', 'romance'], year: 2003, creator: 'Sofia Coppola' });
  const hereditary = await resolve('movie', 'Hereditary', { genres: ['horror'], year: 2018, creator: 'Ari Aster' });
  const stalker = await resolve('movie', 'Stalker', { genres: ['science fiction', 'art house'], year: 1979, creator: 'Andrei Tarkovsky' });
  const pastLives = await resolve('movie', 'Past Lives', { genres: ['romance', 'drama'], year: 2023, creator: 'Celine Song' });
  const barbie = await resolve('movie', 'Barbie', { genres: ['comedy', 'fantasy'], year: 2023, creator: 'Greta Gerwig' });

  const normalPeople = await resolve('book', 'Normal People', { genres: ['literary fiction', 'romance'], year: 2018, creator: 'Sally Rooney' });
  const duneBook = await resolve('book', 'Dune', { genres: ['science fiction'], year: 1965, creator: 'Frank Herbert' });
  const beloved = await resolve('book', 'Beloved', { genres: ['literary fiction'], year: 1987, creator: 'Toni Morrison' });
  const pachinko = await resolve('book', 'Pachinko', { genres: ['historical fiction'], year: 2017, creator: 'Min Jin Lee' });
  const infiniteJest = await resolve('book', 'Infinite Jest', { genres: ['postmodern'], year: 1996, creator: 'David Foster Wallace' });
  const piranesi = await resolve('book', 'Piranesi', { genres: ['fantasy'], year: 2020, creator: 'Susanna Clarke' });
  const atomic = await resolve('book', 'Atomic Habits', { genres: ['self-help', 'nonfiction'], year: 2018, creator: 'James Clear' });

  return [
    {
      name: 'Maya', age: 27, city: 'Brooklyn', gender: 'woman', intent: 'both', autoReply: true,
      bio: 'Letterboxd four stars minimum. Will make you a playlist unprompted.',
      music: [radiohead, phoebe, sufjan, fka],
      movie: [moodForLove, parasite, lostTrans, pastLives],
      book: [normalPeople, pachinko, piranesi],
    },
    {
      name: 'Dev', age: 29, city: 'Brooklyn', gender: 'man', intent: 'both', autoReply: true,
      bio: 'Slow cinema apologist. Currently 300 pages into something unreadable.',
      music: [radiohead, aphex, sufjan],
      movie: [stalker, moodForLove, parasite],
      book: [infiniteJest, piranesi, duneBook],
    },
    {
      name: 'Nina', age: 25, city: 'Queens', gender: 'woman', intent: 'friends',
      bio: 'Horror girlie. I will not be watching that quiet French film with you.',
      music: [fka, aphex, kendrick],
      movie: [hereditary, parasite, eeaao],
      book: [beloved, piranesi],
    },
    {
      name: 'Arjun', age: 31, city: 'Manhattan', gender: 'man', intent: 'dating', autoReply: true,
      bio: 'Reads nonfiction on the train, cries at Wong Kar-wai on the weekend.',
      music: [radiohead, phoebe, kendrick],
      movie: [moodForLove, pastLives, lostTrans],
      book: [pachinko, normalPeople, beloved],
    },
    {
      name: 'Sofia', age: 24, city: 'Brooklyn', gender: 'woman', intent: 'both',
      bio: 'Pop maximalist, unrepentant. Yes I have seen Barbie four times.',
      music: [taylor, beyonce, phoebe],
      movie: [barbie, eeaao, pastLives],
      book: [normalPeople, atomic],
    },
    {
      name: 'Theo', age: 33, city: 'Jersey City', gender: 'man', intent: 'friends',
      bio: 'Ambient music for focus, sci-fi doorstoppers for everything else.',
      music: [aphex, radiohead],
      movie: [stalker, eeaao, hereditary],
      book: [duneBook, infiniteJest, piranesi],
    },
    {
      name: 'Ishaan', age: 26, city: 'Manhattan', gender: 'man', intent: 'dating',
      bio: 'Hip hop head with a soft spot for devastating Korean dramas.',
      music: [kendrick, fka, beyonce],
      movie: [parasite, pastLives, eeaao],
      book: [beloved, pachinko],
    },
    {
      name: 'Priya', age: 28, city: 'Brooklyn', gender: 'woman', intent: 'dating', autoReply: true,
      bio: 'Folk music, long books, and an unreasonable number of tote bags.',
      music: [phoebe, sufjan, radiohead],
      movie: [lostTrans, pastLives, moodForLove],
      book: [normalPeople, piranesi, pachinko],
    },
    {
      name: 'Ravi', age: 30, city: 'Queens', gender: 'man', intent: 'both',
      bio: 'If it has a 40-minute runtime and no dialogue, I am already seated.',
      music: [aphex, radiohead, sufjan],
      movie: [stalker, moodForLove],
      book: [infiniteJest, duneBook],
    },
    {
      name: 'Aisha', age: 23, city: 'Brooklyn', gender: 'woman', intent: 'friends',
      bio: 'Making everyone I meet watch Everything Everywhere. No exceptions.',
      music: [beyonce, taylor, fka],
      movie: [eeaao, barbie, parasite],
      book: [normalPeople, atomic],
    },
    {
      name: 'Kabir', age: 32, city: 'Hoboken', gender: 'man', intent: 'dating',
      bio: 'Jazz, Tarkovsky, and a running list of books I pretend to have read.',
      music: [radiohead, aphex],
      movie: [stalker, moodForLove, lostTrans],
      book: [infiniteJest, beloved],
    },
    {
      name: 'Leila', age: 29, city: 'Manhattan', gender: 'woman', intent: 'both',
      bio: 'Historical fiction and films that ruin me. Recommend accordingly.',
      music: [phoebe, sufjan],
      movie: [pastLives, moodForLove, lostTrans],
      book: [pachinko, beloved, normalPeople],
    },
    {
      name: 'Jonas', age: 27, city: 'Brooklyn', gender: 'nonbinary', intent: 'both', autoReply: true,
      bio: 'Electronic music, weird fiction, and films that refuse to explain themselves.',
      music: [aphex, fka, radiohead],
      movie: [stalker, eeaao, hereditary],
      book: [piranesi, infiniteJest],
    },
    {
      name: 'Meera', age: 25, city: 'Jersey City', gender: 'woman', intent: 'friends',
      bio: 'Will talk about Pachinko until you leave the room.',
      music: [sufjan, phoebe, taylor],
      movie: [pastLives, lostTrans],
      book: [pachinko, normalPeople, beloved],
    },
    {
      name: 'Owen', age: 34, city: 'Queens', gender: 'man', intent: 'friends',
      bio: 'Horror, industrial music, and a genuinely alarming Dune obsession.',
      music: [aphex, fka],
      movie: [hereditary, stalker],
      book: [duneBook, piranesi],
    },
    {
      name: 'Zara', age: 26, city: 'Brooklyn', gender: 'woman', intent: 'dating',
      bio: 'Kendrick on repeat, Bong Joon-ho on rotation, always mid-book.',
      music: [kendrick, beyonce, fka],
      movie: [parasite, eeaao, hereditary],
      book: [beloved, atomic],
    },
    {
      name: 'Finn', age: 28, city: 'Hoboken', gender: 'man', intent: 'both',
      bio: 'Indie folk, slow films, and books with maps in the front.',
      music: [sufjan, phoebe, radiohead],
      movie: [lostTrans, moodForLove, pastLives],
      book: [piranesi, duneBook, normalPeople],
    },
    {
      name: 'Tulika', age: 24, city: 'Manhattan', gender: 'woman', intent: 'both',
      bio: 'Pop for the commute, literary fiction for the guilt.',
      music: [taylor, phoebe, beyonce],
      movie: [barbie, pastLives, eeaao],
      book: [normalPeople, pachinko],
    },
    {
      name: 'Mukul', age: 30, city: 'Brooklyn', gender: 'man', intent: 'friends',
      bio: 'Ambient, arthouse, and the same three books on repeat.',
      music: [aphex, radiohead, sufjan],
      movie: [stalker, moodForLove, eeaao],
      book: [infiniteJest, duneBook, piranesi],
    },
    {
      name: 'Ana', age: 31, city: 'Queens', gender: 'woman', intent: 'dating', autoReply: true,
      bio: 'I peaked emotionally during In the Mood for Love and never recovered.',
      music: [phoebe, radiohead, fka],
      movie: [moodForLove, pastLives, parasite],
      book: [normalPeople, beloved, pachinko],
    },
  ];
}

function toStored(items: SeedItem[]) {
  return items.map((i) => ({
    key: i.key,
    label: i.label,
    ...(i.subtitle ? { subtitle: i.subtitle } : {}),
    meta: {
      ...(i.genres ? { genres: i.genres } : {}),
      ...(i.year ? { year: i.year } : {}),
      ...(i.creator ? { creator: i.creator } : {}),
    },
    addedAt: new Date().toISOString(),
  }));
}

export async function seed(db: Db): Promise<number> {
  // Clear previous seed accounts (cascades to their taste and swipes).
  await db.query("DELETE FROM users WHERE email LIKE '%@seed.wavelength.test'");

  console.log('Resolving seed favourites against the live providers...');
  const people = await buildPeople();

  for (const person of people) {
    const id = newId();
    const email = `${person.name.toLowerCase()}@seed.wavelength.test`;

    await db.query(
      `INSERT INTO users (id, email, name, age, gender, city, bio, intent, seeking,
                          photo_url, interested_in, onboarding_stage,
                          taste_profile_completeness, is_synthetic, auto_reply)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'everyone',$9,'["everyone"]'::jsonb,
               'complete',100,TRUE,$10)`,
      [
        id,
        email,
        person.name,
        person.age,
        person.gender,
        person.city,
        person.bio,
        person.intent,
        avatarFor(id, person.name),
        person.autoReply ?? false,
      ],
    );
    await db.query('INSERT INTO privacy_settings (user_id) VALUES ($1)', [id]);

    for (const [table, column, items] of [
      ['music_profile', 'top_artists', person.music],
      ['movie_profile', 'favorite_films', person.movie],
      ['book_profile', 'favorite_books', person.book],
    ] as const) {
      await db.query(
        `INSERT INTO ${table} (user_id, ${column}, source, last_synced_at)
         VALUES ($1, $2::jsonb, 'seed', now())`,
        [id, JSON.stringify(toStored(items))],
      );
    }

    // Keep item_popularity honest so inverse-popularity weighting is meaningful.
    for (const [domain, items] of [
      ['music', person.music],
      ['movie', person.movie],
      ['book', person.book],
    ] as const) {
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
  }

  return people.length;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const { seedCommunities, seedMembershipsAndDrops } = await import('./seedCommunities.js');

  const db = await getDb();
  await runMigrations(db);

  const count = await seed(db);
  console.log(`Seeded ${count} demo people.`);

  const communities = await seedCommunities(db);
  console.log(`Seeded ${communities} communities.`);

  const { joins, drops } = await seedMembershipsAndDrops(db);
  console.log(`Joined ${joins} memberships, posted ${drops} drops.`);

  await closeDb();
}
