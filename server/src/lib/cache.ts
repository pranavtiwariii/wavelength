/**
 * Tiny TTL cache. Third-party metadata lookups are repetitive and rate-limited
 * (NFR 9: cache aggressively, never call them live during a swipe session), and
 * a process-local map is enough until there's a Redis to point at.
 */
export class TtlCache<T> {
  constructor(
    private readonly ttlMs: number,
    private readonly maxEntries = 500,
  ) {}

  private readonly store = new Map<string, { value: T; expiresAt: number }>();

  get(key: string): T | undefined {
    const hit = this.store.get(key);
    if (!hit) return undefined;
    if (hit.expiresAt < Date.now()) {
      this.store.delete(key);
      return undefined;
    }
    // Refresh insertion order so hot keys survive eviction.
    this.store.delete(key);
    this.store.set(key, hit);
    return hit.value;
  }

  set(key: string, value: T): void {
    if (this.store.size >= this.maxEntries) {
      const oldest = this.store.keys().next().value;
      if (oldest !== undefined) this.store.delete(oldest);
    }
    this.store.set(key, { value, expiresAt: Date.now() + this.ttlMs });
  }
}
