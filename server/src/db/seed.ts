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
  intent: 'dating' | 'friends' | 'both';
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
      name: 'Maya', age: 27, city: 'Brooklyn', intent: 'both',
      bio: 'Letterboxd four stars minimum. Will make you a playlist unprompted.',
      music: [radiohead, phoebe, sufjan, fka],
      movie: [moodForLove, parasite, lostTrans, pastLives],
      book: [normalPeople, pachinko, piranesi],
    },
    {
      name: 'Dev', age: 29, city: 'Brooklyn', intent: 'both',
      bio: 'Slow cinema apologist. Currently 300 pages into something unreadable.',
      music: [radiohead, aphex, sufjan],
      movie: [stalker, moodForLove, parasite],
      book: [infiniteJest, piranesi, duneBook],
    },
    {
      name: 'Nina', age: 25, city: 'Queens', intent: 'friends',
      bio: 'Horror girlie. I will not be watching that quiet French film with you.',
      music: [fka, aphex, kendrick],
      movie: [hereditary, parasite, eeaao],
      book: [beloved, piranesi],
    },
    {
      name: 'Arjun', age: 31, city: 'Manhattan', intent: 'dating',
      bio: 'Reads nonfiction on the train, cries at Wong Kar-wai on the weekend.',
      music: [radiohead, phoebe, kendrick],
      movie: [moodForLove, pastLives, lostTrans],
      book: [pachinko, normalPeople, beloved],
    },
    {
      name: 'Sofia', age: 24, city: 'Brooklyn', intent: 'both',
      bio: 'Pop maximalist, unrepentant. Yes I have seen Barbie four times.',
      music: [taylor, beyonce, phoebe],
      movie: [barbie, eeaao, pastLives],
      book: [normalPeople, atomic],
    },
    {
      name: 'Theo', age: 33, city: 'Jersey City', intent: 'friends',
      bio: 'Ambient music for focus, sci-fi doorstoppers for everything else.',
      music: [aphex, radiohead],
      movie: [stalker, eeaao, hereditary],
      book: [duneBook, infiniteJest, piranesi],
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
      `INSERT INTO users (id, email, name, age, city, bio, intent, interested_in,
                          onboarding_stage, taste_profile_completeness)
       VALUES ($1,$2,$3,$4,$5,$6,$7,'["everyone"]'::jsonb,'complete',100)`,
      [id, email, person.name, person.age, person.city, person.bio, person.intent],
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
  const db = await getDb();
  await runMigrations(db);
  const count = await seed(db);
  console.log(`Seeded ${count} demo people.`);
  await closeDb();
}
