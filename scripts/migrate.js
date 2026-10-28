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
  databaseUrl = process.env.MIGRATION_DATABASE_URL || process.env.DATABASE_URL,
} = {}) {
  if (!databaseUrl)
    throw new Error('DATABASE_URL is required. Configure a local .env from .env.example.');
  const parsed = new URL(databaseUrl);
  const dbName = decodeURIComponent(parsed.pathname.slice(1));
  const localHost = ['', 'localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname);
  if (seed && (!dbName.endsWith('_dev') || process.env.APP_MODE !== 'demo' || !localHost)) {
    throw new Error('Seeding is restricted to a local database ending in _dev with APP_MODE=demo.');
  }
  const client = new Client({
    connectionString: databaseUrl,
    application_name: 'queueless-migration-runner',
  });
  await client.connect();
  let locked = false;
  try {
    if (!seed) {
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
    const dir = path.join(ROOT, 'database', seed ? 'seeds' : 'migrations');
    const files = fs
      .readdirSync(dir)
      .filter(f => /^\d{3}_[a-z0-9_]+\.sql$/.test(f))
      .sort();
    if (!seed) {
      const { rows } = await client.query(
        'SELECT version FROM public.schema_migrations ORDER BY version'
      );
      const available = new Set(files);
      const missing = rows.map(row => row.version).filter(version => !available.has(version));
      if (missing.length)
        throw new Error(
          `Applied migration file(s) are missing: ${missing.join(', ')}. Restore from version control; do not recreate history.`
        );
    }
    for (const file of files) {
      const sql = fs.readFileSync(path.join(dir, file), 'utf8');
      const digest = hash(sql);
      if (!seed) {
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
        await client.query(sql);
        if (!seed)
          await client.query(
            'INSERT INTO public.schema_migrations(version, sha256) VALUES ($1, $2)',
            [file, digest]
          );
        await client.query('COMMIT');
        console.info(`${seed ? 'Seeded' : 'Applied'} ${file}`);
      } catch (error) {
        await client.query('ROLLBACK');
        throw new Error(`${seed ? 'Seed' : 'Migration'} ${file} failed: ${error.message}`, {
          cause: error,
        });
      }
    }
    console.info(seed ? 'Synthetic development seeds complete.' : 'Migrations are current.');
  } finally {
    if (locked)
      await client
        .query('SELECT pg_advisory_unlock(hashtextextended($1, 0))', [LOCK_KEY])
        .catch(() => {});
    await client.end();
  }
}

if (require.main === module) {
  runMigrations({ seed: process.argv.includes('--seed') }).catch(error => {
    console.error(`[QueueLess DB] ${error.message || error.code || 'database connection failed'}`);
    process.exitCode = 1;
  });
}
module.exports = { runMigrations };
