import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createTestDb, type Db } from '../db/index.js';
import { runMigrations } from '../db/migrate.js';
import { ApiError } from '../lib/errors.js';
import { normaliseIdentifier } from '../lib/identifier.js';
import { requestOtp, verifyOtp, verifyToken } from './auth.js';

let db: Db;

beforeAll(async () => {
  db = await createTestDb();
  await runMigrations(db);
});

afterAll(async () => {
  await db.close();
});

describe('normaliseIdentifier', () => {
  it('lowercases and trims email so casing cannot fork an account', () => {
    expect(normaliseIdentifier('  Daiwik@Example.COM ')).toEqual({
      value: 'daiwik@example.com',
      channel: 'email',
    });
  });

  it('strips formatting from phone numbers into E.164', () => {
    expect(normaliseIdentifier('+1 (415) 555-0123')).toEqual({
      value: '+14155550123',
      channel: 'phone',
    });
  });

  it('rejects a phone number with no country code', () => {
    expect(() => normaliseIdentifier('4155550123')).toThrow(ApiError);
  });

  it('rejects a malformed email', () => {
    expect(() => normaliseIdentifier('nope@nope')).toThrow(ApiError);
  });
});

describe('OTP sign-in', () => {
  it('creates a user on first verification and issues a usable token', async () => {
    const { devCode } = await requestOtp(db, 'first@example.com');
    const result = await verifyOtp(db, 'first@example.com', devCode!);

    expect(result.isNewUser).toBe(true);
    expect(result.onboardingStage).toBe('basics');
    await expect(verifyToken(result.token)).resolves.toBe(result.userId);
  });

  it('returns the same user on a second sign-in', async () => {
    const a = await requestOtp(db, 'repeat@example.com');
    const first = await verifyOtp(db, 'repeat@example.com', a.devCode!);
    const b = await requestOtp(db, 'repeat@example.com');
    const second = await verifyOtp(db, 'repeat@example.com', b.devCode!);

    expect(second.userId).toBe(first.userId);
    expect(second.isNewUser).toBe(false);
  });

  it('treats a differently-cased email as the same account', async () => {
    const a = await requestOtp(db, 'case@example.com');
    const first = await verifyOtp(db, 'case@example.com', a.devCode!);
    const b = await requestOtp(db, 'CASE@Example.com');
    const second = await verifyOtp(db, 'Case@EXAMPLE.com', b.devCode!);

    expect(second.userId).toBe(first.userId);
  });

  it('rejects a wrong code', async () => {
    await requestOtp(db, 'wrong@example.com');
    await expect(verifyOtp(db, 'wrong@example.com', '000000')).rejects.toThrow(/not valid/);
  });

  it('refuses to reuse a consumed code', async () => {
    const { devCode } = await requestOtp(db, 'replay@example.com');
    await verifyOtp(db, 'replay@example.com', devCode!);
    await expect(verifyOtp(db, 'replay@example.com', devCode!)).rejects.toThrow(/not valid/);
  });

  it('locks out after too many wrong attempts', async () => {
    const { devCode } = await requestOtp(db, 'brute@example.com');
    for (let i = 0; i < 5; i++) {
      await expect(verifyOtp(db, 'brute@example.com', '111111')).rejects.toThrow();
    }
    // Even the correct code is refused once the attempt budget is spent.
    await expect(verifyOtp(db, 'brute@example.com', devCode!)).rejects.toThrow(/Too many attempts/);
  });

  it('rate limits repeated code requests for one identifier', async () => {
    for (let i = 0; i < 5; i++) await requestOtp(db, 'flood@example.com');
    await expect(requestOtp(db, 'flood@example.com')).rejects.toThrow(/Too many codes/);
  });

  it('never stores the raw code', async () => {
    const { devCode } = await requestOtp(db, 'secret@example.com');
    const { rows } = await db.query<{ code_hash: string }>(
      `SELECT code_hash FROM auth_otp_codes WHERE identifier = $1`,
      ['secret@example.com'],
    );
    expect(rows[0]!.code_hash).not.toContain(devCode!);
    expect(rows[0]!.code_hash).toHaveLength(64);
  });

  it('rejects a tampered token', async () => {
    await expect(verifyToken('not.a.jwt')).rejects.toThrow(/session has expired/);
  });
});
