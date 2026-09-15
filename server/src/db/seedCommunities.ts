import type { Db } from './index.js';
import { createCommunity } from '../services/communities.js';

/**
 * The community dataset. Tags are matched against the genres and creators
 * already in a user's taste profile, which is how suggestions are ranked —
 * so every tag here has to be a word the providers actually return.
 */
export const COMMUNITIES = [
  {
    slug: 'a24-and-slow-cinema',
    name: 'A24 & Slow Cinema',
    description: 'Long takes, longer silences. Films that trust you to sit with them.',
    domain: 'movie',
    accent: 'movie',
    tags: ['art house', 'drama', 'philosophical', 'andrei tarkovsky', 'wong kar-wai',
           'sofia coppola', 'celine song', 'ari aster'],
  },
  {
    slug: 'bedroom-pop',
    name: 'Bedroom Pop & Sad Guitars',
    description: 'Recorded at 2am, listened to at 2am.',
    domain: 'music',
    accent: 'music',
    tags: ['indie folk', 'sadcore', 'chamber pop', 'phoebe bridgers', 'sufjan stevens',
           'singer-songwriter'],
  },
  {
    slug: 'finished-the-series',
    name: 'People Who Actually Finish Series',
    description: 'No abandoned trilogies. No 40%-read doorstoppers.',
    domain: 'book',
    accent: 'book',
    tags: ['science fiction', 'epic', 'fantasy', 'frank herbert', 'postmodern',
           'david foster wallace'],
  },
  {
    slug: 'dark-academia',
    name: '#DarkAcademia',
    description: 'Libraries, obsession, and books that feel like winter.',
    domain: 'book',
    accent: 'book',
    tags: ['literary fiction', 'historical', 'postmodern', 'susanna clarke',
           'toni morrison', 'gothic'],
  },
  {
    slug: 'horror-heads',
    name: 'Horror Heads',
    description: 'For people whose comfort film is somebody else’s nightmare.',
    domain: 'movie',
    accent: 'movie',
    tags: ['horror', 'psychological horror', 'thriller', 'ari aster'],
  },
  {
    slug: 'idm-and-ambient',
    name: 'IDM & Ambient',
    description: 'Music to think to. Or to avoid thinking to.',
    domain: 'music',
    accent: 'music',
    tags: ['idm', 'experimental electronic', 'ambient', 'aphex twin', 'experimental'],
  },
  {
    slug: 'pop-maximalists',
    name: 'Pop Maximalists',
    description: 'Unrepentant. The bridge goes hard and we will discuss it.',
    domain: 'music',
    accent: 'music',
    tags: ['pop', 'r&b', 'country pop', 'taylor swift', 'beyoncé', 'art pop'],
  },
  {
    slug: 'subtitles-club',
    name: 'Subtitles Club',
    description: 'One inch of subtitles, a whole world of film.',
    domain: 'movie',
    accent: 'movie',
    tags: ['bong joon-ho', 'wong kar-wai', 'black comedy', 'romance', 'art house'],
  },
  {
    slug: 'rap-and-verses',
    name: 'Rap & Verses',
    description: 'Bars, structure, and the occasional 12-minute closing track.',
    domain: 'music',
    accent: 'music',
    tags: ['hip hop', 'conscious hip hop', 'kendrick lamar', 'r&b'],
  },
  {
    slug: 'sally-rooney-industrial-complex',
    name: 'The Sally Rooney Industrial Complex',
    description: 'Emotionally unavailable people, beautifully written.',
    domain: 'book',
    accent: 'book',
    tags: ['literary fiction', 'romance', 'sally rooney', 'min jin lee', 'drama'],
  },
  {
    slug: 'sci-fi-doorstoppers',
    name: 'Sci-Fi Doorstoppers',
    description: 'If it doesn’t have an appendix, is it even worldbuilding?',
    domain: 'book',
    accent: 'book',
    tags: ['science fiction', 'epic', 'frank herbert', 'fantasy'],
  },
  {
    slug: 'radiohead-support-group',
    name: 'Radiohead Support Group',
    description: 'We have opinions about the album order. All of them.',
    domain: 'music',
    accent: 'music',
    tags: ['alternative rock', 'art rock', 'radiohead', 'experimental'],
  },
];

export async function seedCommunities(db: Db): Promise<number> {
  for (const community of COMMUNITIES) {
    await createCommunity(db, community);
  }
  return COMMUNITIES.length;
}

/**
 * Puts seeded people into the communities their taste actually matches, and
 * has them drop a few of their favourites, so both features have content on
 * first run instead of empty states.
 */
export async function seedMembershipsAndDrops(db: Db): Promise<{ joins: number; drops: number }> {
  const { rows: people } = await db.query<{ id: string }>(
    "SELECT id FROM users WHERE email LIKE '%@seed.wavelength.test'",
  );
  const { rows: communities } = await db.query<{ id: string; tags: unknown }>(
    'SELECT id, tags FROM communities',
  );

  const { suggestCommunities, joinCommunity } = await import('../services/communities.js');
  const { createDrop } = await import('../services/drops.js');

  let joins = 0;
  let drops = 0;

  for (const person of people) {
    const suggestions = await suggestCommunities(db, person.id, 3);
    for (const community of suggestions) {
      await joinCommunity(db, person.id, community.id);
      joins++;
    }

    // Drop one favourite into the first community they joined.
    const home = suggestions[0];
    if (!home) continue;

    const { rows } = await db.query<Record<string, any>>(
      `SELECT COALESCE(m.top_artists,'[]'::jsonb) AS music,
              COALESCE(mo.favorite_films,'[]'::jsonb) AS movie,
              COALESCE(b.favorite_books,'[]'::jsonb) AS book
         FROM users u
         LEFT JOIN music_profile m ON m.user_id=u.id
         LEFT JOIN movie_profile mo ON mo.user_id=u.id
         LEFT JOIN book_profile b ON b.user_id=u.id
        WHERE u.id=$1`,
      [person.id],
    );
    const row = rows[0];
    if (!row) continue;

    for (const domain of ['music', 'movie', 'book'] as const) {
      const raw = row[domain];
      const items = (typeof raw === 'string' ? JSON.parse(raw) : raw) as Array<Record<string, any>>;
      const pick = items?.[0];
      if (!pick) continue;

      await createDrop(db, person.id, {
        domain,
        itemKey: pick.key,
        itemLabel: pick.label,
        itemSubtitle: pick.subtitle,
        caption: CAPTIONS[Math.floor(Math.random() * CAPTIONS.length)]!,
        communityId: home.id,
      });
      drops++;
      break; // one drop each keeps the seeded feed readable
    }
  }

  return { joins, drops };
}

const CAPTIONS = [
  'Still thinking about this one.',
  'Genuinely changed how I see the whole genre.',
  'Putting this here so somebody argues with me.',
  'Third time this month. No notes.',
  'If you know, you know.',
  'Criminally underrated and I will die on this hill.',
];
