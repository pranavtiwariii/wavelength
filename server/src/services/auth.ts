import { createHash, randomInt, timingSafeEqual } from 'node:crypto';
import { SignJWT, jwtVerify } from 'jose';
import { config } from '../config.js';
import type { Db } from '../db/index.js';
import { ApiError } from '../lib/errors.js';
import { newId } from '../lib/ids.js';
import { normaliseIdentifier, type Channel } from '../lib/identifier.js';

const secretKey = new TextEncoder().encode(config.jwtSecret);

/** Codes are stored only as a salted hash - a DB leak must not yield live OTPs. */
function hashCode(code: string, identifier: string): string {
  return createHash('sha256').update(`${code}:${identifier}:${config.jwtSecret}`).digest('hex');
}

function constantTimeEquals(a: string, b: string): boolean {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ab.length !== bb.length) return false;
  return timingSafeEqual(ab, bb);
}

export interface RequestOtpResult {
  channel: Channel;
  expiresInSeconds: number;
  /** Populated only when DEV_ECHO_OTP is on. Never set in production. */
  devCode?: string;
}

export async function requestOtp(db: Db, rawIdentifier: string): Promise<RequestOtpResult> {
  const { value: identifier, channel } = normaliseIdentifier(rawIdentifier);

  // Coarse abuse guard: cap sends per identifier per window.
  const { rows: recent } = await db.query<{ count: string }>(
    `SELECT count(*)::text AS count FROM auth_otp_codes
      WHERE identifier = $1 AND created_at > now() - interval '15 minutes'`,
    [identifier],
  );
  if (Number(recent[0]?.count ?? 0) >= 5) {
    throw ApiError.tooMany('otp_rate_limited', 'Too many codes requested. Try again in a few minutes.');
  }

  const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
  const expiresAt = new Date(Date.now() + config.otpTtlSeconds * 1000);

  await db.query(
    `INSERT INTO auth_otp_codes (id, identifier, channel, code_hash, expires_at)
     VALUES ($1, $2, $3, $4, $5)`,
    [newId(), identifier, channel, hashCode(code, identifier), expiresAt.toISOString()],
  );

  // TODO(phase1): send via a real SMS/email provider.
  if (config.devEchoOtp) {
    console.log(`[auth] OTP for ${identifier}: ${code}`);
  }

  return {
    channel,
    expiresInSeconds: config.otpTtlSeconds,
    ...(config.devEchoOtp ? { devCode: code } : {}),
  };
}

export interface VerifyOtpResult {
  token: string;
  userId: string;
  isNewUser: boolean;
  onboardingStage: string;
}

export async function verifyOtp(
  db: Db,
  rawIdentifier: string,
  code: string,
): Promise<VerifyOtpResult> {
  const { value: identifier, channel } = normaliseIdentifier(rawIdentifier);

  const { rows } = await db.query<{
    id: string;
    code_hash: string;
    attempts: number;
    expires_at: string;
    consumed_at: string | null;
  }>(
    `SELECT id, code_hash, attempts, expires_at, consumed_at
       FROM auth_otp_codes
      WHERE identifier = $1
      ORDER BY created_at DESC
      LIMIT 1`,
    [identifier],
  );

  const record = rows[0];
  const genericFailure = ApiError.unauthorized('otp_invalid', 'That code is not valid.');
  if (!record) throw genericFailure;
  if (record.consumed_at) throw genericFailure;
  if (new Date(record.expires_at).getTime() < Date.now()) {
    throw ApiError.unauthorized('otp_expired', 'That code has expired. Request a new one.');
  }
  if (record.attempts >= config.otpMaxAttempts) {
    throw ApiError.tooMany('otp_attempts_exceeded', 'Too many attempts. Request a new code.');
  }

  if (!constantTimeEquals(record.code_hash, hashCode(code.trim(), identifier))) {
    await db.query('UPDATE auth_otp_codes SET attempts = attempts + 1 WHERE id = $1', [record.id]);
    throw genericFailure;
  }

  return db.transaction(async (tx) => {
    await tx.query('UPDATE auth_otp_codes SET consumed_at = now() WHERE id = $1', [record.id]);

    const column = channel === 'email' ? 'email' : 'phone';
    const { rows: existing } = await tx.query<{ id: string; onboarding_stage: string }>(
      `SELECT id, onboarding_stage FROM users WHERE ${column} = $1`,
      [identifier],
    );

    if (existing[0]) {
      return {
        token: await issueToken(existing[0].id),
        userId: existing[0].id,
        isNewUser: false,
        onboardingStage: existing[0].onboarding_stage,
      };
    }

    const userId = newId();
    await tx.query(`INSERT INTO users (id, ${column}) VALUES ($1, $2)`, [userId, identifier]);
    // Default to the most private-friendly working state; user edits in settings.
    await tx.query('INSERT INTO privacy_settings (user_id) VALUES ($1)', [userId]);

    return {
      token: await issueToken(userId),
      userId,
      isNewUser: true,
      onboardingStage: 'basics',
    };
  });
}

export async function issueToken(userId: string): Promise<string> {
  return new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setIssuer(config.jwtIssuer)
    .setExpirationTime(config.accessTokenTtl)
    .sign(secretKey);
}

export async function verifyToken(token: string): Promise<string> {
  try {
    const { payload } = await jwtVerify(token, secretKey, { issuer: config.jwtIssuer });
    if (!payload.sub) throw new Error('missing sub');
    return payload.sub;
  } catch {
    throw ApiError.unauthorized('invalid_token', 'Your session has expired. Sign in again.');
  }
}
