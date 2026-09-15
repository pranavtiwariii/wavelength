import { Type } from '@sinclair/typebox';
import type { FastifyPluginAsync } from 'fastify';
import {
  acceptConnection,
  countIncomingRequests,
  declineConnection,
  listIncomingRequests,
} from '../services/connections.js';
import {
  createDrop,
  deleteDrop,
  listCommunityDrops,
  listFeed,
  listUserDrops,
  react,
} from '../services/drops.js';
import {
  getCommunity,
  joinCommunity,
  leaveCommunity,
  listCommunities,
  listMembers,
  suggestCommunities,
} from '../services/communities.js';

const MiniUser = Type.Object({
  id: Type.String(),
  name: Type.Union([Type.String(), Type.Null()]),
  photoUrl: Type.Union([Type.String(), Type.Null()]),
});

const DropSchema = Type.Object({
  id: Type.String(),
  domain: Type.String(),
  itemKey: Type.String(),
  itemLabel: Type.String(),
  itemSubtitle: Type.Union([Type.String(), Type.Null()]),
  itemImage: Type.Union([Type.String(), Type.Null()]),
  caption: Type.Union([Type.String(), Type.Null()]),
  createdAt: Type.String(),
  author: MiniUser,
  community: Type.Union([
    Type.Object({ id: Type.String(), name: Type.String(), slug: Type.String() }),
    Type.Null(),
  ]),
  likeCount: Type.Integer(),
  saveCount: Type.Integer(),
  likedByMe: Type.Boolean(),
  savedByMe: Type.Boolean(),
  sharedWithMe: Type.Boolean(),
});

const CommunitySchema = Type.Object({
  id: Type.String(),
  slug: Type.String(),
  name: Type.String(),
  description: Type.Union([Type.String(), Type.Null()]),
  domain: Type.Union([Type.String(), Type.Null()]),
  tags: Type.Array(Type.String()),
  accent: Type.Union([Type.String(), Type.Null()]),
  memberCount: Type.Integer(),
  joined: Type.Boolean(),
  matchedTags: Type.Optional(Type.Array(Type.String())),
});

export const graphRoutes: FastifyPluginAsync = async (app) => {
  // --- Connections -------------------------------------------------------
  app.get(
    '/connections/requests',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['connections'],
        summary: 'Connection requests waiting on you.',
        security: [{ bearerAuth: [] }],
        response: {
          200: Type.Object({
            requests: Type.Array(
              Type.Object({
                id: Type.String(),
                user: Type.Object({
                  id: Type.String(),
                  name: Type.Union([Type.String(), Type.Null()]),
                  age: Type.Union([Type.Integer(), Type.Null()]),
                  city: Type.Union([Type.String(), Type.Null()]),
                  bio: Type.Union([Type.String(), Type.Null()]),
                  photoUrl: Type.Union([Type.String(), Type.Null()]),
                }),
                message: Type.Union([Type.String(), Type.Null()]),
                createdAt: Type.String(),
                overallScore: Type.Integer(),
              }),
            ),
            count: Type.Integer(),
          }),
        },
      },
    },
    async (req) => {
      const requests = await listIncomingRequests(app.db, req.userId);
      return { requests, count: requests.length };
    },
  );

  app.get(
    '/connections/requests/count',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['connections'],
        security: [{ bearerAuth: [] }],
        response: { 200: Type.Object({ count: Type.Integer() }) },
      },
    },
    async (req) => ({ count: await countIncomingRequests(app.db, req.userId) }),
  );

  app.post(
    '/connections/requests/:id/accept',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['connections'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ id: Type.String() }),
        response: { 200: Type.Object({ matchId: Type.String() }) },
      },
    },
    async (req) => {
      const { id } = req.params as { id: string };
      return { matchId: await acceptConnection(app.db, id, req.userId) };
    },
  );

  app.post(
    '/connections/requests/:id/decline',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['connections'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ id: Type.String() }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { id } = req.params as { id: string };
      await declineConnection(app.db, id, req.userId);
      return { ok: true };
    },
  );

  // --- Content Drops -----------------------------------------------------
  app.get(
    '/drops',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['drops'],
        summary: 'The Drops feed.',
        security: [{ bearerAuth: [] }],
        response: { 200: Type.Object({ drops: Type.Array(DropSchema) }) },
      },
    },
    async (req) => ({ drops: await listFeed(app.db, req.userId) }),
  );

  app.get(
    '/users/:userId/drops',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['drops'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ userId: Type.String() }),
        response: { 200: Type.Object({ drops: Type.Array(DropSchema) }) },
      },
    },
    async (req) => {
      const { userId } = req.params as { userId: string };
      return { drops: await listUserDrops(app.db, req.userId, userId) };
    },
  );

  app.post(
    '/drops',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['drops'],
        summary: 'Share something you like.',
        security: [{ bearerAuth: [] }],
        body: Type.Object({
          domain: Type.Union([
            Type.Literal('music'),
            Type.Literal('movie'),
            Type.Literal('book'),
          ]),
          itemKey: Type.String({ minLength: 1 }),
          itemLabel: Type.String({ minLength: 1 }),
          itemSubtitle: Type.Optional(Type.String()),
          itemImage: Type.Optional(Type.String()),
          caption: Type.Optional(Type.String({ maxLength: 400 })),
          communityId: Type.Optional(Type.String()),
        }),
        response: { 200: DropSchema },
      },
    },
    async (req) => createDrop(app.db, req.userId, req.body as never),
  );

  app.post(
    '/drops/:id/react',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['drops'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ id: Type.String() }),
        body: Type.Object({
          kind: Type.Union([Type.Literal('like'), Type.Literal('save')]),
          on: Type.Boolean(),
        }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { id } = req.params as { id: string };
      const { kind, on } = req.body as { kind: 'like' | 'save'; on: boolean };
      await react(app.db, req.userId, id, kind, on);
      return { ok: true };
    },
  );

  app.delete(
    '/drops/:id',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['drops'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ id: Type.String() }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { id } = req.params as { id: string };
      await deleteDrop(app.db, req.userId, id);
      return { ok: true };
    },
  );

  // --- Communities -------------------------------------------------------
  app.get(
    '/communities',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['communities'],
        security: [{ bearerAuth: [] }],
        response: {
          200: Type.Object({
            communities: Type.Array(CommunitySchema),
            suggested: Type.Array(CommunitySchema),
          }),
        },
      },
    },
    async (req) => ({
      communities: await listCommunities(app.db, req.userId),
      suggested: await suggestCommunities(app.db, req.userId),
    }),
  );

  app.get(
    '/communities/:slug',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['communities'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ slug: Type.String() }),
        response: {
          200: Type.Object({
            community: CommunitySchema,
            members: Type.Array(
              Type.Object({
                id: Type.String(),
                name: Type.Union([Type.String(), Type.Null()]),
                age: Type.Union([Type.Integer(), Type.Null()]),
                city: Type.Union([Type.String(), Type.Null()]),
                photoUrl: Type.Union([Type.String(), Type.Null()]),
              }),
            ),
            drops: Type.Array(DropSchema),
          }),
        },
      },
    },
    async (req) => {
      const { slug } = req.params as { slug: string };
      const community = await getCommunity(app.db, req.userId, slug);
      return {
        community,
        members: await listMembers(app.db, community.id),
        drops: await listCommunityDrops(app.db, req.userId, community.id),
      };
    },
  );

  app.post(
    '/communities/:id/join',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['communities'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ id: Type.String() }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { id } = req.params as { id: string };
      await joinCommunity(app.db, req.userId, id);
      return { ok: true };
    },
  );

  app.post(
    '/communities/:id/leave',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['communities'],
        security: [{ bearerAuth: [] }],
        params: Type.Object({ id: Type.String() }),
        response: { 200: Type.Object({ ok: Type.Boolean() }) },
      },
    },
    async (req) => {
      const { id } = req.params as { id: string };
      await leaveCommunity(app.db, req.userId, id);
      return { ok: true };
    },
  );
};
