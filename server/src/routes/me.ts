import { Type } from '@sinclair/typebox';
import type { FastifyPluginAsync } from 'fastify';
import { ApiError } from '../lib/errors.js';

const MeResponse = Type.Object({
  id: Type.String(),
  email: Type.Union([Type.String(), Type.Null()]),
  phone: Type.Union([Type.String(), Type.Null()]),
  name: Type.Union([Type.String(), Type.Null()]),
  age: Type.Union([Type.Integer(), Type.Null()]),
  gender: Type.Union([Type.String(), Type.Null()]),
  seeking: Type.Union([Type.String(), Type.Null()]),
  photoUrl: Type.Union([Type.String(), Type.Null()]),
  intent: Type.Union([Type.String(), Type.Null()]),
  city: Type.Union([Type.String(), Type.Null()]),
  bio: Type.Union([Type.String(), Type.Null()]),
  onboardingStage: Type.String(),
  tasteProfileCompleteness: Type.Integer(),
});

export const meRoutes: FastifyPluginAsync = async (app) => {
  app.get(
    '/me',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['me'],
        summary: 'The signed-in user.',
        security: [{ bearerAuth: [] }],
        response: { 200: MeResponse },
      },
    },
    async (req) => {
      const { rows } = await app.db.query<Record<string, any>>(
        `SELECT id, email, phone, name, age, gender, seeking, photo_url, intent,
                city, bio, onboarding_stage, taste_profile_completeness
           FROM users WHERE id = $1`,
        [req.userId],
      );
      const u = rows[0];
      if (!u) throw ApiError.notFound('user_not_found', 'That account no longer exists.');
      return {
        id: u.id,
        email: u.email,
        phone: u.phone,
        name: u.name,
        age: u.age,
        gender: u.gender,
        seeking: u.seeking,
        photoUrl: u.photo_url,
        intent: u.intent,
        city: u.city,
        bio: u.bio,
        onboardingStage: u.onboarding_stage,
        tasteProfileCompleteness: u.taste_profile_completeness,
      };
    },
  );
};
