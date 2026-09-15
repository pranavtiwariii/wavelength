import { Type } from '@sinclair/typebox';
import type { FastifyPluginAsync } from 'fastify';
import { bootstrapPool } from '../services/bootstrap.js';
import { assertDomain } from '../services/taste.js';
import { listStarters } from '../services/starters.js';

export const onboardingRoutes: FastifyPluginAsync = async (app) => {
  app.get(
    '/taste/starters',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['taste'],
        summary: 'Curated picks for the onboarding taste step.',
        security: [{ bearerAuth: [] }],
        querystring: Type.Object({ domain: Type.String() }),
        response: {
          200: Type.Object({
            items: Type.Array(
              Type.Object({
                key: Type.String(),
                label: Type.String(),
                subtitle: Type.Optional(Type.String()),
                imageUrl: Type.Optional(Type.String()),
                meta: Type.Optional(
                  Type.Object({
                    genres: Type.Optional(Type.Array(Type.String())),
                    year: Type.Optional(Type.Integer()),
                    creator: Type.Optional(Type.String()),
                  }),
                ),
                popularity: Type.Integer(),
              }),
            ),
          }),
        },
      },
    },
    async (req) => {
      const { domain } = req.query as { domain: string };
      return { items: await listStarters(app.db, assertDomain(domain)) };
    },
  );

  app.post(
    '/me/bootstrap',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['me'],
        summary: 'Generate a matching pool around the signed-in user\'s taste.',
        security: [{ bearerAuth: [] }],
        response: {
          200: Type.Object({
            created: Type.Integer(),
            matches: Type.Integer(),
            requests: Type.Integer(),
          }),
        },
      },
    },
    async (req) => bootstrapPool(app.db, req.userId),
  );

  app.post(
    '/me/pool/expand',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['me'],
        summary: 'Add more people to the pool, shaped by your taste.',
        security: [{ bearerAuth: [] }],
        response: {
          200: Type.Object({
            created: Type.Integer(),
            matches: Type.Integer(),
            requests: Type.Integer(),
          }),
        },
      },
    },
    async (req) => bootstrapPool(app.db, req.userId, true),
  );
};
