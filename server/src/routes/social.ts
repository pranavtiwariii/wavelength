import { Type } from '@sinclair/typebox';
import type { FastifyPluginAsync } from 'fastify';
import { ApiError } from '../lib/errors.js';
import { generateNarrative } from '../services/narrative/index.js';
import {
  blockUser,
  buildDiscoveryFeed,
  getPairCompatibility,
  recycleDiscovery,
  listMatches,
  listMessages,
  recordSwipe,
  reportUser,
  sendMessage,
  unmatch,
} from '../services/social.js';

const PublicUser = Type.Object({
  id: Type.String(),
  name: Type.Union([Type.String(), Type.Null()]),
  age: Type.Union([Type.Integer(), Type.Null()]),
  gender: Type.Union([Type.String(), Type.Null()]),
  city: Type.Union([Type.String(), Type.Null()]),
  bio: Type.Union([Type.String(), Type.Null()]),
  photoUrl: Type.Union([Type.String(), Type.Null()]),
});

const Dna = Type.Object({
  niche: Type.Number(),
  melancholic: Type.Number(),
  contemporary: Type.Number(),
  maximalist: Type.Number(),
  challenging: Type.Number(),
});

const Highlight = Type.Object({ domain: Type.String(), label: Type.String() });

const DiscoveryCard = Type.Object({
  user: PublicUser,
  overallScore: Type.Integer(),
  music: Type.Union([Type.Integer(), Type.Null()]),
  movie: Type.Union([Type.Integer(), Type.Null()]),
  book: Type.Union([Type.Integer(), Type.Null()]),
  sharedHighlights: Type.Array(Highlight),
  divergenceHighlights: Type.Array(
    Type.Object({ domain: Type.String(), label: Type.String(), heldBy: Type.String() }),
  ),
  tasteDna: Dna,
  yourTasteDna: Dna,
  narrative: Type.Union([Type.String(), Type.Null()]),
});

export const socialRoutes: FastifyPluginAsync = async (app) => {
  app.get(
    '/discovery',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['discovery'],
        summary: 'Compatibility-ranked candidates for the signed-in user.',
        security: [{ bearerAuth: [] }],
        querystring: Type.Object({
          minScore: Type.Optional(Type.Integer({ minimum: 0, maximum: 100 })),
          minAge: Type.Optional(Type.Integer({ minimum: 18, maximum: 120 })),
          maxAge: Type.Optional(Type.Integer({ minimum: 18, maximum: 120 })),
        }),
        response: { 200: Type.Object({ cards: Type.Array(DiscoveryCard) }) },
      },
    },
    async (req) => {
      const q = req.query as { minScore?: number; minAge?: number; maxAge?: number };
      return { cards: await buildDiscoveryFeed(app.db, req.userId, 20, q) };
    },
  );

  app.get(
    '/discovery/:userId/narrative',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['discovery'],
        summary: 'The AI compatibility narrative for one pairing (spec 3.5).',
        security: [{ bearerAuth: [] }],
        params: Type.Object({ userId: Type.String() }),
        response: { 200: Type.Object({ narrative: Type.String() }) },
      },
    },
    async (req) => {
      const { userId } = req.params as { userId: string };
      const pair = await getPairCompatibility(app.db, req.userId, userId);
      if (!pair) throw ApiError.notFound('user_not_found', 'That person is no longer available.');

      const { rows } = await app.db.query<{ name: string | null }>(
        'SELECT name FROM users WHERE id = $1',
        [req.userId],
      );

      const narrative = await generateNarrative({
        viewerName: rows[0]?.name ?? null,
        otherName: pair.user.name,
        overallScore: pair.overallScore,
        shared: pair.sharedHighlights,
        divergences: pair.divergenceHighlights.map((d) => ({
          domain: d.domain,
          label: d.label,
          heldByOther: d.heldBy === userId,
        })),
      });
      return { narrative };
    },
  );

  app.post(
    '/discovery/recycle',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['discovery'],
        summary: 'Clear your passes so the queue can be worked again.',
        security: [{ bearerAuth: [] }],
        response: { 200: Type.Object({ restored: Type.Integer() }) },
      },
    },
    async (req) => ({ restored: await recycleDiscovery(app.db, req.userId) }),
  );

  app.get(
    '/compatibility/:userId',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['discovery'],
        summary: 'Full compatibility breakdown for one pairing.',
        security: [{ bearerAuth: [] }],
        params: Type.Object({ userId: Type.String() }),
        response: {
          200: Type.Object({
            user: PublicUser,
            overallScore: Type.Integer(),
            music: Type.Union([Type.Integer(), Type.Null()]),
            movie: Type.Union([Type.Integer(), Type.Null()]),
            book: Type.Union([Type.Integer(), Type.Null()]),
            sharedHighlights: Type.Array(Highlight),
            divergenceHighlights: Type.Array(
              Type.Object({ domain: Type.String(), label: Type.String(), heldBy: Type.String() }),
            ),
            tasteDna: Dna,
            yourTasteDna: Dna,
          }),
        },
      },
    },
    async (req) => {
      const { userId } = req.params as { userId: string };
      const pair = await getPairCompatibility(app.db, req.userId, userId);
      if (!pair) throw ApiError.notFound('user_not_found', 'That person is no longer available.');
      return pair;
    },
  );

  app.post(
    '/swipe',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['discovery'],
        summary: 'Like or pass on a candidate. A mutual like creates a match.',
        security: [{ bearerAuth: [] }],
        body: Type.Object({
          targetId: Type.String(),
          direction: Type.Union([Type.Literal('like'), Type.Literal('pass')]),
        }),
        response: {
          200: Type.Object({
            matched: Type.Boolean(),
            matchId: Type.Union([Type.String(), Type.Null()]),
            requested: Type.Boolean(),
          }),
        },
      },
    },
    async (req) => {
      const { targetId, direction } = req.body as {
        targetId: string;
        direction: 'like' | 'pass';
      };
      return recordSwipe(app.db, req.userId, targetId, direction);
    },
  );

  app.get(
    '/matches',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['matches'],
        security: [{ bearerAuth: [] }],
        response: {
          200: Type.Object({
            matches: Type.Array(
              Type.Object({
                matchId: Type.String(),
                user: PublicUser,
                overallScore: Type.Integer(),
                lastMessage: Type.Union([Type.String(), Type.Null()]),
                lastMessageAt: Type.Union([Type.String(), Type.Null()]),
                unread: Type.Boolean(),
              }),
            ),
          }),
        },
      },
    },
    async (req) => ({ matches: await listMatches(app.db, req.userId) }),
  );

  const MessageSchema = Type.Object({
    id: Type.String(),
    senderId: Type.String(),
    content: Type.String(),
    sentAt: Type.String(),
    mine: Type.Boolean(),
  });

  app.get(
    '/matches/:matchId/messages',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['matches'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ matchId: Type.String() }),
        response: { 200: Type.Object({ messages: Type.Array(MessageSchema) }) },
      },
    },
    async (req) => {
      const { matchId } = req.params as { matchId: string };
      return { messages: await listMessages(app.db, matchId, req.userId) };
    },
  );

  app.post(
    '/matches/:matchId/messages',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['matches'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ matchId: Type.String() }),
        body: Type.Object({ content: Type.String({ minLength: 1, maxLength: 2000 }) }),
        response: { 200: MessageSchema },
      },
    },
    async (req) => {
      const { matchId } = req.params as { matchId: string };
      const { content } = req.body as { content: string };
      return sendMessage(app.db, matchId, req.userId, content);
    },
  );

  app.post(
    '/matches/:matchId/unmatch',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['matches'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ matchId: Type.String() }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { matchId } = req.params as { matchId: string };
      await unmatch(app.db, matchId, req.userId);
      return { ok: true };
    },
  );

  app.post(
    '/users/:userId/block',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['safety'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ userId: Type.String() }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { userId } = req.params as { userId: string };
      await blockUser(app.db, req.userId, userId);
      return { ok: true };
    },
  );

  app.post(
    '/users/:userId/report',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['safety'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ userId: Type.String() }),
        body: Type.Object({
          reason: Type.String({ minLength: 1, maxLength: 100 }),
          detail: Type.Optional(Type.String({ maxLength: 1000 })),
        }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { userId } = req.params as { userId: string };
      const { reason, detail } = req.body as { reason: string; detail?: string };
      await reportUser(app.db, req.userId, userId, reason, detail);
      return { ok: true };
    },
  );
};
