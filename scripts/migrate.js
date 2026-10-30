'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { Client } = require('pg');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const LOCK_KEY = 'QueueLess SQL migrations v1';
const ROOT = path.resolve(__dirname, '..');
const hash = sql => crypto.createHash('sha256').update(sql).digest('hex');

async function runMigrations({
  seed = false,
  largeSeed = false,
  down = false,
  databaseUrl = process.env.MIGRATION_DATABASE_URL || process.env.DATABASE_URL,
} = {}) {
  if (!databaseUrl)
    throw new Error('DATABASE_URL is required. Configure a local .env from .env.example.');
  const parsed = new URL(databaseUrl);
  const dbName = decodeURIComponent(parsed.pathname.slice(1));
  const localHost = ['', 'localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname);
  if ((seed || largeSeed) && (!dbName.endsWith('_dev') || process.env.APP_MODE !== 'demo' || !localHost)) {
    throw new Error('Seeding is restricted to a local database ending in _dev with APP_MODE=demo.');
  }
  if ((seed && largeSeed) || (down && (seed || largeSeed)))
    throw new Error('Choose exactly one of migration up, --down, --seed, or --large-seed.');
  const client = new Client({
    connectionString: databaseUrl,
    application_name: 'queueless-migration-runner',
  });
  await client.connect();
  let locked = false;
  const isMigration = !seed && !largeSeed;
  try {
    if (isMigration) {
      await client.query('SELECT pg_advisory_lock(hashtextextended($1, 0))', [LOCK_KEY]);
      locked = true;
      await client.query(`CREATE TABLE IF NOT EXISTS public.schema_migrations (
        version text PRIMARY KEY, sha256 char(64) NOT NULL, applied_at timestamptz NOT NULL DEFAULT now()
      )`);
      await client.query('REVOKE ALL ON TABLE public.schema_migrations FROM PUBLIC');
      await client.query(`DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'queueless_app') THEN
          EXECUTE 'REVOKE ALL ON TABLE public.schema_migrations FROM queueless_app';
        END IF;
      END $$`);
      const { rows: checksumColumn } = await client.query(
        "SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='schema_migrations' AND column_name='sha256'"
      );
      if (!checksumColumn.length)
        throw new Error(
          'Legacy schema_migrations table has no checksums. Review its applied versions and reconcile it manually before continuing.'
        );
    }
    const dir = path.join(ROOT, 'database', seed || largeSeed ? 'seeds' : 'migrations');
    let files = fs
      .readdirSync(dir)
      .filter(f => /^\d{3}_[a-z0-9_]+\.sql$/.test(f))
      .sort();
    if (seed) files = files.filter(file => file === '001_synthetic_seed.sql');
    if (largeSeed) files = files.filter(file => file === '002_large_explain_seed.sql');
    if (!seed && !largeSeed) {
      const { rows } = await client.query(
        'SELECT version FROM public.schema_migrations ORDER BY version'
      );
      const available = new Set(files);
      const missing = rows.map(row => row.version).filter(version => !available.has(version));
      if (missing.length)
        throw new Error(
          `Applied migration file(s) are missing: ${missing.join(', ')}. Restore from version control; do not recreate history.`
        );

      if (down) {
        const { rows: applied } = await client.query(
          'SELECT version, sha256 FROM public.schema_migrations ORDER BY version DESC LIMIT 1'
        );
        if (!applied.length) {
          console.info('No applied migration to roll back.');
          return;
        }
        const file = applied[0].version;
        const sql = fs.readFileSync(path.join(dir, file), 'utf8');
        const digest = hash(sql);
        if (applied[0].sha256.trim() !== digest)
          throw new Error(`Applied migration ${file} was modified; refusing rollback.`);
        const sections = splitMigration(sql, file);
        await client.query('BEGIN');
        try {
          await client.query(sections.down);
          await client.query('DELETE FROM public.schema_migrations WHERE version = $1', [file]);
          await client.query('COMMIT');
          console.info(`Rolled back ${file}`);
        } catch (error) {
          await client.query('ROLLBACK');
          throw new Error(`Rollback ${file} failed: ${error.message}`, { cause: error });
        }
        return;
      }
    }
    for (const file of files) {
      const sql = fs.readFileSync(path.join(dir, file), 'utf8');
      const digest = hash(sql);
      if (isMigration) {
        const { rows } = await client.query(
          'SELECT sha256 FROM public.schema_migrations WHERE version = $1',
          [file]
        );
        if (rows.length) {
          if (rows[0].sha256.trim() !== digest)
            throw new Error(
              `Applied migration ${file} was modified. Restore it and create a new forward migration.`
            );
          continue;
        }
      }
      await client.query('BEGIN');
      try {
        await client.query(isMigration ? splitMigration(sql, file).up : sql);
        if (isMigration)
          await client.query(
            'INSERT INTO public.schema_migrations(version, sha256) VALUES ($1, $2)',
            [file, digest]
          );
        await client.query('COMMIT');
        console.info(`${seed || largeSeed ? 'Seeded' : 'Applied'} ${file}`);
      } catch (error) {
        await client.query('ROLLBACK');
        throw new Error(`${seed || largeSeed ? 'Seed' : 'Migration'} ${file} failed: ${error.message}`, {
          cause: error,
        });
      }
    }
    console.info(seed || largeSeed ? 'Synthetic development seeds complete.' : 'Migrations are current.');
  } finally {
    if (locked)
      await client
        .query('SELECT pg_advisory_unlock(hashtextextended($1, 0))', [LOCK_KEY])
        .catch(() => {});
    await client.end();
  }
}

function splitMigration(sql, file) {
  const match = sql.match(/^-- UP\s*\n([\s\S]*?)^-- DOWN\s*\n([\s\S]*)$/m);
  if (!match || !match[1].trim() || !match[2].trim())
    throw new Error(`${file} must include non-empty -- UP and -- DOWN sections.`);
  return { up: match[1], down: match[2] };
}

if (require.main === module) {
  runMigrations({
    seed: process.argv.includes('--seed'),
    largeSeed: process.argv.includes('--large-seed'),
    down: process.argv.includes('--down'),
  }).catch(error => {
    console.error(`[QueueLess DB] ${error.message || error.code || 'database connection failed'}`);
    process.exitCode = 1;
  });
}
module.exports = { runMigrations, splitMigration };
