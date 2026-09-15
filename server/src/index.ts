import { assertProductionSafety, config } from './config.js';
import { buildApp } from './app.js';
import { closeDb, getDb } from './db/index.js';
import { runMigrations } from './db/migrate.js';

assertProductionSafety();

const db = await getDb();
await runMigrations(db);

const app = await buildApp(db);

try {
  await app.listen({ port: config.port, host: config.host });
  app.log.info(`Wavelength API on :${config.port} (db: ${db.driver})`);
} catch (err) {
  app.log.error(err);
  process.exit(1);
}

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, async () => {
    await app.close();
    await closeDb();
    process.exit(0);
  });
}
