import cors from '@fastify/cors';
import swagger from '@fastify/swagger';
import Fastify, { type FastifyInstance } from 'fastify';
import { config } from './config.js';
import type { Db } from './db/index.js';
import { ApiError } from './lib/errors.js';
import { authRoutes } from './routes/auth.js';
import { meRoutes } from './routes/me.js';
import { tasteRoutes } from './routes/taste.js';
import { verifyToken } from './services/auth.js';

declare module 'fastify' {
  interface FastifyInstance {
    db: Db;
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
  interface FastifyRequest {
    userId: string;
  }
}
import type { FastifyReply, FastifyRequest } from 'fastify';

export async function buildApp(db: Db): Promise<FastifyInstance> {
  const app = Fastify({
    logger: config.env === 'test' ? false : { level: config.env === 'production' ? 'info' : 'debug' },
  });

  app.decorate('db', db);
  app.decorateRequest('userId', '');

  await app.register(cors, { origin: true });
  await app.register(swagger, {
    openapi: {
      info: { title: 'Wavelength API', version: '0.1.0' },
      components: {
        securitySchemes: {
          bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
        },
      },
    },
  });

  app.decorate('authenticate', async (req: FastifyRequest, _reply: FastifyReply) => {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw ApiError.unauthorized('missing_token', 'Sign in to continue.');
    }
    req.userId = await verifyToken(header.slice('Bearer '.length));
  });

  app.setErrorHandler((err, req, reply) => {
    if (err instanceof ApiError) {
      return reply.status(err.statusCode).send({ error: { code: err.code, message: err.message } });
    }
    if ((err as { validation?: unknown }).validation) {
      return reply
        .status(400)
        .send({ error: { code: 'validation_failed', message: (err as Error).message } });
    }
    req.log.error({ err }, 'unhandled error');
    return reply
      .status(500)
      .send({ error: { code: 'internal_error', message: 'Something went wrong.' } });
  });

  app.get('/health', { schema: { tags: ['meta'] } }, async () => ({
    status: 'ok',
    driver: db.driver,
  }));

  await app.register(authRoutes);
  await app.register(meRoutes);
  await app.register(tasteRoutes);

  return app;
}
