import { config } from '../config.js';

/** Minimal query surface both drivers satisfy. Keeps call sites driver-agnostic. */
export interface Db {
  query<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<{ rows: T[] }>;
  /** Run a multi-statement SQL script (migrations). No parameters. */
  exec(sql: string): Promise<void>;
  transaction<T>(fn: (tx: Db) => Promise<T>): Promise<T>;
  close(): Promise<void>;
  readonly driver: 'pg' | 'pglite';
}

let instance: Db | undefined;

async function createPgDb(url: string): Promise<Db> {
  const { default: pg } = await import('pg');
  const pool = new pg.Pool({ connectionString: url });

  const wrap = (runner: { query: (s: string, p?: unknown[]) => Promise<any> }): Db => ({
    driver: 'pg',
    async query(sql, params) {
      const res = await runner.query(sql, params as unknown[]);
      return { rows: res.rows };
    },
    async exec(sql) {
      await runner.query(sql);
    },
    async transaction(fn) {
      // Nested transaction on an existing client: reuse the same connection.
      return fn(wrap(runner));
    },
    async close() {
      /* pooled client is released by the outer owner */
    },
  });

  return {
    driver: 'pg',
    async query(sql, params) {
      const res = await pool.query(sql, params as unknown[]);
      return { rows: res.rows };
    },
    async exec(sql) {
      await pool.query(sql);
    },
    async transaction(fn) {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const out = await fn(wrap(client));
        await client.query('COMMIT');
        return out;
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    },
    async close() {
      await pool.end();
    },
  };
}

async function createPgliteDb(dir: string): Promise<Db> {
  const { PGlite } = await import('@electric-sql/pglite');
  // ':memory:' is honoured by PGlite for ephemeral test databases.
  const pg = await PGlite.create(dir === ':memory:' ? undefined : dir);

  /**
   * PGlite is a SINGLE connection. Without serialisation, two concurrent HTTP
   * requests interleave their statements - and a BEGIN from one request can
   * swallow another's queries into its transaction, which deadlocks the whole
   * process. Every operation therefore goes through this queue, and a
   * transaction holds the queue for its full BEGIN..COMMIT span.
   */
  let tail: Promise<unknown> = Promise.resolve();
  function serialise<T>(op: () => Promise<T>): Promise<T> {
    // Chain regardless of whether the previous op resolved or rejected.
    const run = tail.then(op, op);
    tail = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  }

  const rawQuery = async <T>(sql: string, params?: unknown[]) => {
    const res = await pg.query(sql, params as unknown[]);
    return { rows: res.rows as T[] };
  };

  /** Bypasses the queue - only handed to a transaction body, which already holds it. */
  const unlocked: Db = {
    driver: 'pglite',
    query: rawQuery,
    async exec(sql) {
      await pg.exec(sql);
    },
    async transaction(fn) {
      // Already inside a transaction: reuse it rather than nesting BEGIN.
      return fn(unlocked);
    },
    async close() {
      /* owned by the outer instance */
    },
  };

  const self: Db = {
    driver: 'pglite',
    query: (sql, params) => serialise(() => rawQuery(sql, params)),
    exec: (sql) =>
      serialise(async () => {
        // pg.query() speaks the extended protocol (single statement only);
        // exec() speaks the simple protocol and accepts a whole script.
        await pg.exec(sql);
      }),
    transaction: (fn) =>
      serialise(async () => {
        await pg.query('BEGIN');
        try {
          const out = await fn(unlocked);
          await pg.query('COMMIT');
          return out;
        } catch (err) {
          await pg.query('ROLLBACK');
          throw err;
        }
      }),
    async close() {
      await pg.close();
    },
  };
  return self;
}

export async function getDb(): Promise<Db> {
  if (instance) return instance;
  instance = config.databaseUrl
    ? await createPgDb(config.databaseUrl)
    : await createPgliteDb(config.pgliteDir);
  return instance;
}

/** Fresh in-memory database, for tests. Never cached. */
export async function createTestDb(): Promise<Db> {
  return createPgliteDb(':memory:');
}

export async function closeDb(): Promise<void> {
  if (!instance) return;
  await instance.close();
  instance = undefined;
}
