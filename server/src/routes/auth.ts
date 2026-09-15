import { Type } from '@sinclair/typebox';
import type { FastifyPluginAsync } from 'fastify';
import { requestOtp, verifyOtp } from '../services/auth.js';

export const authRoutes: FastifyPluginAsync = async (app) => {
  app.post(
    '/auth/request-otp',
    {
      schema: {
        tags: ['auth'],
        summary: 'Send a one-time code to an email address or phone number.',
        body: Type.Object({
          identifier: Type.String({ minLength: 3, description: 'Email or E.164 phone number' }),
        }),
        response: {
          200: Type.Object({
            channel: Type.Union([Type.Literal('email'), Type.Literal('phone')]),
            expiresInSeconds: Type.Integer(),
            devCode: Type.Optional(Type.String()),
          }),
        },
      },
    },
    async (req) => {
      const { identifier } = req.body as { identifier: string };
      return requestOtp(app.db, identifier);
    },
  );

  app.post(
    '/auth/verify-otp',
    {
      schema: {
        tags: ['auth'],
        summary: 'Exchange a one-time code for an access token.',
        body: Type.Object({
          identifier: Type.String({ minLength: 3 }),
          code: Type.String({ minLength: 6, maxLength: 6 }),
        }),
        response: {
          200: Type.Object({
            token: Type.String(),
            userId: Type.String(),
            isNewUser: Type.Boolean(),
            onboardingStage: Type.String(),
          }),
        },
      },
    },
    async (req) => {
      const { identifier, code } = req.body as { identifier: string; code: string };
      return verifyOtp(app.db, identifier, code);
    },
  );
};
