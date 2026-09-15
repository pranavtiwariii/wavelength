import { ApiError } from './errors.js';

export type Channel = 'email' | 'phone';

export interface NormalisedIdentifier {
  value: string;
  channel: Channel;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const E164_RE = /^\+[1-9]\d{7,14}$/;

/**
 * Normalise before hashing or storing so "A@B.com" and "a@b.com" are one
 * account, and phone numbers are always compared in E.164.
 */
export function normaliseIdentifier(raw: string): NormalisedIdentifier {
  const trimmed = raw.trim();

  if (trimmed.includes('@')) {
    const value = trimmed.toLowerCase();
    if (!EMAIL_RE.test(value)) {
      throw ApiError.badRequest('invalid_identifier', 'That email address looks malformed.');
    }
    return { value, channel: 'email' };
  }

  // Strip spaces, dashes and brackets; require an explicit country code.
  const digits = trimmed.replace(/[\s\-().]/g, '');
  if (!E164_RE.test(digits)) {
    throw ApiError.badRequest(
      'invalid_identifier',
      'Enter a phone number in international format, e.g. +14155550123.',
    );
  }
  return { value: digits, channel: 'phone' };
}
