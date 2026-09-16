import { Type } from '@sinclair/typebox';
import type { FastifyPluginAsync } from 'fastify';
import { newId } from '../lib/ids.js';
import { countUnread, listNotifications, markAllRead } from '../services/notifications.js';

export const notificationRoutes: FastifyPluginAsync = async (app) => {
  app.get(
    '/notifications',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['notifications'],
        summary: 'In-app notifications (proposal 5.2).',
        security: [{ bearerAuth: [] }],
        response: {
          200: Type.Object({
            notifications: Type.Array(
              Type.Object({
                id: Type.String(),
                kind: Type.String(),
                body: Type.String(),
                target: Type.Union([Type.String(), Type.Null()]),
                readAt: Type.Union([Type.String(), Type.Null()]),
                createdAt: Type.String(),
                actor: Type.Union([
                  Type.Object({
                    id: Type.String(),
                    name: Type.Union([Type.String(), Type.Null()]),
                    photoUrl: Type.Union([Type.String(), Type.Null()]),
                  }),
                  Type.Null(),
                ]),
              }),
            ),
            unread: Type.Integer(),
          }),
        },
      },
    },
    async (req) => ({
      notifications: await listNotifications(app.db, req.userId),
      unread: await countUnread(app.db, req.userId),
    }),
  );

  app.post(
    '/notifications/read',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['notifications'],
        security: [{ bearerAuth: [] }],
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      await markAllRead(app.db, req.userId);
      return { ok: true };
    },
  );

  /**
   * Proposal 6.2: explainability satisfaction. Pilot users rate the
   * "why you matched" explanation 1-5 for clarity and usefulness, which is
   * otherwise the one evaluation metric with no data behind it.
   */
  app.post(
    '/compatibility/:userId/rate',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['discovery'],
        summary: 'Rate how clear the match explanation was.',
        security: [{ bearerAuth: [] }],
        params: Type.Object({ userId: Type.String() }),
        body: Type.Object({ rating: Type.Integer({ minimum: 1, maximum: 5 }) }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { userId } = req.params as { userId: string };
      const { rating } = req.body as { rating: number };
      await app.db.query(
        `INSERT INTO explanation_ratings (id, rater_id, subject_id, rating)
         VALUES ($1,$2,$3,$4)
         ON CONFLICT (rater_id, subject_id) DO UPDATE
           SET rating = EXCLUDED.rating, created_at = now()`,
        [newId(), req.userId, userId, rating],
      );
      return { ok: true };
    },
  );

  /**
   * The proposal's evaluation metrics (section 6), computed from stored data.
   * Having this as an endpoint means the numbers in the report come from the
   * system rather than from a spreadsheet.
   */
  app.get(
    '/metrics',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['meta'],
        summary: 'Evaluation metrics from proposal section 6.',
        security: [{ bearerAuth: [] }],
        response: {
          200: Type.Object({
            matchToConnectionRate: Type.Number(),
            connectionAcceptanceRate: Type.Number(),
            tasteSignatureCompletionRate: Type.Number(),
            matchExplanationDensity: Type.Number(),
            explainabilitySatisfaction: Type.Union([Type.Number(), Type.Null()]),
            sampleSizes: Type.Object({
              swipes: Type.Integer(),
              requests: Type.Integer(),
              users: Type.Integer(),
              ratings: Type.Integer(),
            }),
          }),
        },
      },
    },
    async () => {
      const one = async (sql: string): Promise<number> => {
        const { rows } = await app.db.query<{ v: string | null }>(sql);
        return Number(rows[0]?.v ?? 0);
      };

      const swipes = await one("SELECT count(*)::text AS v FROM swipes WHERE direction = 'like'");
      const requests = await one('SELECT count(*)::text AS v FROM connection_requests');
      const accepted = await one(
        "SELECT count(*)::text AS v FROM connection_requests WHERE status = 'accepted'",
      );
      const answered = await one(
        "SELECT count(*)::text AS v FROM connection_requests WHERE status IN ('accepted','declined')",
      );
      const users = await one('SELECT count(*)::text AS v FROM users');
      const complete = await one(
        'SELECT count(*)::text AS v FROM users WHERE taste_profile_completeness >= 20',
      );
      const ratings = await one('SELECT count(*)::text AS v FROM explanation_ratings');

      const { rows: densityRows } = await app.db.query<{ v: string | null }>(
        `SELECT avg(jsonb_array_length(shared_highlights))::text AS v
           FROM compatibility_scores`,
      );
      const { rows: satisfactionRows } = await app.db.query<{ v: string | null }>(
        'SELECT avg(rating)::text AS v FROM explanation_ratings',
      );

      const rate = (numerator: number, denominator: number) =>
        denominator === 0 ? 0 : Number(((numerator / denominator) * 100).toFixed(1));

      return {
        // Proposal 6.1: recommendations that turned into a sent request.
        matchToConnectionRate: rate(requests, swipes),
        connectionAcceptanceRate: rate(accepted, answered),
        tasteSignatureCompletionRate: rate(complete, users),
        matchExplanationDensity: Number(Number(densityRows[0]?.v ?? 0).toFixed(2)),
        explainabilitySatisfaction: satisfactionRows[0]?.v
          ? Number(Number(satisfactionRows[0].v).toFixed(2))
          : null,
        sampleSizes: { swipes, requests, users, ratings },
      };
    },
  );
};
