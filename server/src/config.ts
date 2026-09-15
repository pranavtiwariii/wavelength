import 'dotenv/config';

function optional(key: string): string | undefined {
  const v = process.env[key];
  return v && v.length > 0 ? v : undefined;
}

export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 4000),
  host: process.env.HOST ?? '0.0.0.0',

  /**
   * When set, we talk to a real Postgres server. When absent we fall back to
   * PGlite (Postgres compiled to WASM) persisted under .pgdata/, so the whole
   * stack runs with zero external services installed. Same SQL either way.
   */
  databaseUrl: optional('DATABASE_URL'),
  pgliteDir: process.env.PGLITE_DIR ?? '.pgdata',

  jwtSecret: process.env.JWT_SECRET ?? 'dev-only-insecure-secret-change-me',
  jwtIssuer: 'wavelength',
  accessTokenTtl: process.env.ACCESS_TOKEN_TTL ?? '30d',

  /**
   * In development we have no SMS/email provider wired up, so the OTP is
   * written to the server log and echoed in the API response. This MUST be
   * false in production - it would let anyone log in as anyone.
   */
  devEchoOtp: (process.env.DEV_ECHO_OTP ?? 'true') === 'true',
  otpTtlSeconds: Number(process.env.OTP_TTL_SECONDS ?? 600),
  otpMaxAttempts: Number(process.env.OTP_MAX_ATTEMPTS ?? 5),

  // Phase 1+ - requested from the user when the relevant integration lands.
  spotifyClientId: optional('SPOTIFY_CLIENT_ID'),
  spotifyClientSecret: optional('SPOTIFY_CLIENT_SECRET'),
  tmdbApiKey: optional('TMDB_API_KEY'),
  googleBooksApiKey: optional('GOOGLE_BOOKS_API_KEY'),
  anthropicApiKey: optional('ANTHROPIC_API_KEY'),
} as const;

export function assertProductionSafety(): void {
  if (config.env !== 'production') return;
  const problems: string[] = [];
  if (config.devEchoOtp) problems.push('DEV_ECHO_OTP must be false in production');
  if (config.jwtSecret === 'dev-only-insecure-secret-change-me') {
    problems.push('JWT_SECRET must be set to a real secret in production');
  }
  if (!config.databaseUrl) problems.push('DATABASE_URL must be set in production');
  if (problems.length > 0) {
    throw new Error(`Unsafe production config:\n  - ${problems.join('\n  - ')}`);
  }
}
