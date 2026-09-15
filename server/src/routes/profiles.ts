import { Type } from '@sinclair/typebox';
import type { FastifyPluginAsync } from 'fastify';
import { ApiError } from '../lib/errors.js';
import { newId } from '../lib/ids.js';
import { avatarFor } from '../services/avatars.js';
import { computeCompleteness, TARGET_ITEMS_PER_DOMAIN } from '../services/taste.js';

const TasteItemInput = Type.Object({
  key: Type.String({ minLength: 1 }),
  label: Type.String({ minLength: 1 }),
  subtitle: Type.Optional(Type.String()),
  imageUrl: Type.Optional(Type.String()),
  meta: Type.Optional(
    Type.Object({
      genres: Type.Optional(Type.Array(Type.String())),
      year: Type.Optional(Type.Integer()),
      creator: Type.Optional(Type.String()),
    }),
  ),
});

/**
 * Lets a signed-in user add other people to the pool by hand.
 *
 * The proposal's pilot plan (6.3) calls for supplementing real signups with a
 * curated set of synthetic profiles so the matching engine has enough density
 * to produce meaningful matches before organic adoption. These rows are marked
 * `is_synthetic` so they are never mistaken for real accounts, and they carry
 * no credentials — nobody can sign in as one.
 */
export const profileRoutes: FastifyPluginAsync = async (app) => {
  app.post(
    '/profiles',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['profiles'],
        summary: 'Create a synthetic profile that joins the matching pool.',
        security: [{ bearerAuth: [] }],
        body: Type.Object({
          name: Type.String({ minLength: 1, maxLength: 60 }),
          age: Type.Integer({ minimum: 18, maximum: 120 }),
          gender: Type.Union([
            Type.Literal('woman'),
            Type.Literal('man'),
            Type.Literal('nonbinary'),
          ]),
          intent: Type.Union([
            Type.Literal('dating'),
            Type.Literal('friends'),
            Type.Literal('both'),
          ]),
          city: Type.Optional(Type.String({ maxLength: 80 })),
          bio: Type.Optional(Type.String({ maxLength: 400 })),
          autoReply: Type.Optional(Type.Boolean()),
          music: Type.Optional(Type.Array(TasteItemInput)),
          movie: Type.Optional(Type.Array(TasteItemInput)),
          book: Type.Optional(Type.Array(TasteItemInput)),
        }),
        response: {
          200: Type.Object({ id: Type.String(), photoUrl: Type.String() }),
        },
      },
    },
    async (req) => {
      const body = req.body as Record<string, any>;
      const music = (body.music ?? []) as unknown[];
      const movie = (body.movie ?? []) as unknown[];
      const book = (body.book ?? []) as unknown[];

      if (music.length + movie.length + book.length === 0) {
        throw ApiError.badRequest(
          'no_taste',
          'Give them at least one favourite — otherwise they can never match with anyone.',
        );
      }

      const id = newId();
      const photoUrl = avatarFor(id, body.name as string);
      const completeness = computeCompleteness({
        music: music.length,
        movie: movie.length,
        book: book.length,
      });

      await app.db.query(
        `INSERT INTO users (id, name, age, gender, intent, city, bio, photo_url,
                            onboarding_stage, taste_profile_completeness,
                            is_synthetic, auto_reply, interested_in)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'complete',$9,TRUE,$10,'["everyone"]'::jsonb)`,
        [
          id,
          body.name,
          body.age,
          body.gender,
          body.intent,
          body.city ?? null,
          body.bio ?? null,
          photoUrl,
          completeness,
          body.autoReply ?? true,
        ],
      );
      await app.db.query('INSERT INTO privacy_settings (user_id) VALUES ($1)', [id]);

      const stamped = (items: unknown[]) =>
        JSON.stringify(
          (items as Record<string, unknown>[]).map((i) => ({
            ...i,
            addedAt: new Date().toISOString(),
          })),
        );

      for (const [table, column, items, domain] of [
        ['music_profile', 'top_artists', music, 'music'],
        ['movie_profile', 'favorite_films', movie, 'movie'],
        ['book_profile', 'favorite_books', book, 'book'],
      ] as const) {
        await app.db.query(
          `INSERT INTO ${table} (user_id, ${column}, source, last_synced_at)
           VALUES ($1, $2::jsonb, 'manual', now())`,
          [id, stamped(items)],
        );
        // Keep inverse-popularity weighting honest for the new favourites.
        for (const item of items as Array<{ key: string }>) {
          await app.db.query(
            `INSERT INTO item_popularity (domain, item_key, user_count)
             VALUES ($1,$2,1)
             ON CONFLICT (domain, item_key) DO UPDATE
               SET user_count = item_popularity.user_count + 1, updated_at = now()`,
            [domain, item.key],
          );
        }
      }

      return { id, photoUrl };
    },
  );

  app.get(
    '/profiles/synthetic',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['profiles'],
        summary: 'Profiles added by hand, so they can be reviewed or removed.',
        security: [{ bearerAuth: [] }],
        response: {
          200: Type.Object({
            profiles: Type.Array(
              Type.Object({
                id: Type.String(),
                name: Type.Union([Type.String(), Type.Null()]),
                age: Type.Union([Type.Integer(), Type.Null()]),
                gender: Type.Union([Type.String(), Type.Null()]),
                city: Type.Union([Type.String(), Type.Null()]),
                photoUrl: Type.Union([Type.String(), Type.Null()]),
                autoReply: Type.Boolean(),
                target: Type.Integer(),
              }),
            ),
          }),
        },
      },
    },
    async () => {
      const { rows } = await app.db.query<Record<string, any>>(
        `SELECT id, name, age, gender, city, photo_url, auto_reply
           FROM users WHERE is_synthetic = TRUE ORDER BY created_at DESC`,
      );
      return {
        profiles: rows.map((r) => ({
          id: r.id,
          name: r.name,
          age: r.age,
          gender: r.gender,
          city: r.city,
          photoUrl: r.photo_url,
          autoReply: r.auto_reply,
          target: TARGET_ITEMS_PER_DOMAIN,
        })),
      };
    },
  );

  app.delete(
    '/profiles/:id',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['profiles'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ id: Type.String() }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { id } = req.params as { id: string };
      const { rows } = await app.db.query<{ is_synthetic: boolean }>(
        'SELECT is_synthetic FROM users WHERE id = $1',
        [id],
      );
      if (!rows[0]) throw ApiError.notFound('not_found', 'That profile no longer exists.');
      // Guard: this endpoint must never be able to delete a real account.
      if (!rows[0].is_synthetic) {
        throw ApiError.forbidden('not_synthetic', 'Only added profiles can be removed here.');
      }
      await app.db.query('DELETE FROM users WHERE id = $1', [id]);
      return { ok: true };
    },
  );
};
