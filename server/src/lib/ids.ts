import { randomUUID } from 'node:crypto';

export const newId = (): string => randomUUID();

/**
 * Pairs are stored once, canonically ordered (see the *_pair_ordered CHECK
 * constraints). Always route through here before touching matches or
 * compatibility_scores.
 */
export function orderPair(a: string, b: string): [string, string] {
  return a < b ? [a, b] : [b, a];
}
