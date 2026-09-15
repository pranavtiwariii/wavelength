import { Type } from '@sinclair/typebox';
import type { FastifyPluginAsync } from 'fastify';
import {
  addTasteItem,
  assertDomain,
  getTasteProfile,
  removeTasteItem,
  searchTaste,
} from '../services/taste.js';

const TasteMeta = Type.Object({
  genres: Type.Optional(Type.Array(Type.String())),
  year: Type.Optional(Type.Integer()),
  creator: Type.Optional(Type.String()),
});

const TasteItem = Type.Object({
  key: Type.String(),
  label: Type.String(),
  subtitle: Type.Optional(Type.String()),
  imageUrl: Type.Optional(Type.String()),
  meta: Type.Optional(TasteMeta),
  addedAt: Type.String(),
});

const DomainView = Type.Object({
  items: Type.Array(TasteItem),
  available: Type.Boolean(),
  providerName: Type.String(),
  unavailableReason: Type.Optional(Type.String()),
  target: Type.Integer(),
});

const TasteProfile = Type.Object({
  completeness: Type.Integer(),
  domains: Type.Object({ music: DomainView, movie: DomainView, book: DomainView }),
});

export const tasteRoutes: FastifyPluginAsync = async (app) => {
  app.get(
    '/taste/search',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['taste'],
        summary: 'Search a taste domain for things to add.',
        security: [{ bearerAuth: [] }],
        querystring: Type.Object({
          domain: Type.String(),
          q: Type.String({ minLength: 0 }),
        }),
        response: {
          200: Type.Object({
            results: Type.Array(
              Type.Object({
                key: Type.String(),
                label: Type.String(),
                subtitle: Type.Optional(Type.String()),
                imageUrl: Type.Optional(Type.String()),
                meta: Type.Optional(TasteMeta),
              }),
            ),
          }),
        },
      },
    },
    async (req) => {
      const { domain, q } = req.query as { domain: string; q: string };
      return { results: await searchTaste(assertDomain(domain), q) };
    },
  );

  app.get(
    '/me/taste',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['taste'],
        summary: "The signed-in user's taste profile across all three domains.",
        security: [{ bearerAuth: [] }],
        response: { 200: TasteProfile },
      },
    },
    async (req) => getTasteProfile(app.db, req.userId),
  );

  app.post(
    '/me/taste/:domain/items',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['taste'],
        summary: 'Add a favourite to a taste domain.',
        security: [{ bearerAuth: [] }],
        params: Type.Object({ domain: Type.String() }),
        body: Type.Object({
          key: Type.String({ minLength: 1 }),
          label: Type.String({ minLength: 1 }),
          subtitle: Type.Optional(Type.String()),
          imageUrl: Type.Optional(Type.String()),
          meta: Type.Optional(TasteMeta),
        }),
        response: { 200: TasteProfile },
      },
    },
    async (req) => {
      const { domain } = req.params as { domain: string };
      const body = req.body as {
        key: string;
        label: string;
        subtitle?: string;
        imageUrl?: string;
        meta?: { genres?: string[]; year?: number; creator?: string };
      };
      return addTasteItem(app.db, req.userId, assertDomain(domain), body);
    },
  );

  app.delete(
    '/me/taste/:domain/items',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['taste'],
        summary: 'Remove a favourite from a taste domain.',
        security: [{ bearerAuth: [] }],
        params: Type.Object({ domain: Type.String() }),
        querystring: Type.Object({ key: Type.String({ minLength: 1 }) }),
        response: { 200: TasteProfile },
      },
    },
    async (req) => {
      const { domain } = req.params as { domain: string };
      const { key } = req.query as { key: string };
      return removeTasteItem(app.db, req.userId, assertDomain(domain), key);
    },
  );
};
