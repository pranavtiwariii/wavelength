import { Type } from '@sinclair/typebox';
import type { FastifyPluginAsync } from 'fastify';
import { ApiError } from '../lib/errors.js';

export const profileRoutes: FastifyPluginAsync = async (app) => {
  app.patch(
    '/me',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['me'],
        summary: 'Update the signed-in profile.',
        security: [{ bearerAuth: [] }],
        body: Type.Object({
          name: Type.Optional(Type.String({ minLength: 1, maxLength: 60 })),
          age: Type.Optional(Type.Integer({ minimum: 18, maximum: 120 })),
          gender: Type.Optional(Type.String({ maxLength: 40 })),
          interestedIn: Type.Optional(Type.Array(Type.String({ maxLength: 40 }))),
          intent: Type.Optional(
            Type.Union([Type.Literal('dating'), Type.Literal('friends'), Type.Literal('both')]),
          ),
          city: Type.Optional(Type.String({ maxLength: 80 })),
          bio: Type.Optional(Type.String({ maxLength: 400 })),
          onboardingStage: Type.Optional(Type.String({ maxLength: 30 })),
          domainPriority: Type.Optional(
            Type.Object({
              music: Type.Number({ minimum: 0.5, maximum: 3 }),
              movie: Type.Number({ minimum: 0.5, maximum: 3 }),
              book: Type.Number({ minimum: 0.5, maximum: 3 }),
            }),
          ),
        }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const body = req.body as Record<string, unknown>;

      const columns: Record<string, string> = {
        name: 'name',
        age: 'age',
        gender: 'gender',
        city: 'city',
        bio: 'bio',
        intent: 'intent',
        onboardingStage: 'onboarding_stage',
      };

      const sets: string[] = [];
      const values: unknown[] = [req.userId];

      for (const [field, column] of Object.entries(columns)) {
        if (body[field] === undefined) continue;
        values.push(body[field]);
        sets.push(`${column} = $${values.length}`);
      }
      for (const [field, column] of [
        ['interestedIn', 'interested_in'],
        ['domainPriority', 'domain_priority'],
      ] as const) {
        if (body[field] === undefined) continue;
        values.push(JSON.stringify(body[field]));
        sets.push(`${column} = $${values.length}::jsonb`);
      }

      if (sets.length === 0) {
        throw ApiError.badRequest('nothing_to_update', 'No fields were provided.');
      }

      await app.db.query(
        `UPDATE users SET ${sets.join(', ')}, updated_at = now() WHERE id = $1`,
        values,
      );
      return { ok: true };
    },
  );

  app.get(
    '/me/privacy',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['me'],
        security: [{ bearerAuth: [] }],
        response: {
          200: Type.Object({
            music: Type.String(),
            movie: Type.String(),
            book: Type.String(),
          }),
        },
      },
    },
    async (req) => {
      const { rows } = await app.db.query<Record<string, string>>(
        `SELECT music_visibility, movie_visibility, book_visibility
           FROM privacy_settings WHERE user_id = $1`,
        [req.userId],
      );
      const p = rows[0];
      return {
        music: p?.music_visibility ?? 'full',
        movie: p?.movie_visibility ?? 'full',
        book: p?.book_visibility ?? 'full',
      };
    },
  );

  app.patch(
    '/me/privacy',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['me'],
        summary: 'Per-domain taste visibility (spec 4.8).',
        security: [{ bearerAuth: [] }],
        body: Type.Object({
          music: Type.Optional(Type.String()),
          movie: Type.Optional(Type.String()),
          book: Type.Optional(Type.String()),
        }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const body = req.body as Record<string, string | undefined>;
      const allowed = new Set(['full', 'aggregate', 'hidden']);

      for (const domain of ['music', 'movie', 'book'] as const) {
        const value = body[domain];
        if (value === undefined) continue;
        if (!allowed.has(value)) {
          throw ApiError.badRequest('invalid_visibility', `"${value}" is not a visibility level.`);
        }
        await app.db.query(
          `INSERT INTO privacy_settings (user_id, ${domain}_visibility)
           VALUES ($1, $2)
           ON CONFLICT (user_id) DO UPDATE SET ${domain}_visibility = EXCLUDED.${domain}_visibility`,
          [req.userId, value],
        );
      }
      return { ok: true };
    },
  );
};
