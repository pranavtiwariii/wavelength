import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildApp } from './app.js';
import { createTestDb } from './db/index.js';
import { runMigrations } from './db/migrate.js';

/**
 * Dumps the OpenAPI document to shared/openapi.json.
 *
 * Because the app is Flutter, we can't share TypeScript types across the
 * boundary the way the original spec assumed. This file is the contract
 * instead: the Dart models in app/lib are written against it, and it's the
 * thing to diff when an endpoint changes.
 */
const outPath = join(dirname(fileURLToPath(import.meta.url)), '../../shared/openapi.json');

const db = await createTestDb();
await runMigrations(db);

const app = await buildApp(db);
await app.ready();

const spec = app.swagger();
await mkdir(dirname(outPath), { recursive: true });
await writeFile(outPath, `${JSON.stringify(spec, null, 2)}\n`);

await app.close();
await db.close();

console.log(`Wrote ${outPath}`);
process.exit(0);
