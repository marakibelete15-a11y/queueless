/**
 * @file Plain SQL Migration Runner
 * Purpose: Executes unapplied SQL migrations in numerical order using the pg client.
 * SRS Requirements: SYS-1 (Database Versioning), OPS-1 (Zero-ORM Schema Evolution)
 */

const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const connectionString =
  process.env.DATABASE_URL || 'postgres://queueless:queueless@localhost:5432/queueless_dev';

async function runMigrations() {
  const isSeed = process.argv.includes('--seed');
  const targetDir = isSeed
    ? path.resolve(__dirname, '../database/seeds')
    : path.resolve(__dirname, '../database/migrations');

  console.info(`[QueueLess Migration] Connecting to PostgreSQL...`);
  const client = new Client({ connectionString });

  try {
    await client.connect();

    if (!isSeed) {
      await client.query(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
          version VARCHAR(255) PRIMARY KEY,
          applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
      `);
    }

    const files = fs
      .readdirSync(targetDir)
      .filter(f => f.endsWith('.sql'))
      .sort();

    for (const file of files) {
      if (!isSeed) {
        const { rows } = await client.query(
          'SELECT version FROM schema_migrations WHERE version = $1',
          [file]
        );
        if (rows.length > 0) {
          console.info(`[QueueLess Migration] Skipping applied migration: ${file}`);
          continue;
        }
      }

      console.info(`[QueueLess Migration] Executing ${isSeed ? 'seed' : 'migration'}: ${file}`);
      const sql = fs.readFileSync(path.join(targetDir, file), 'utf8');

      await client.query('BEGIN');
      try {
        if (sql.trim().length > 0) {
          await client.query(sql);
        }
        if (!isSeed) {
          await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [file]);
        }
        await client.query('COMMIT');
        console.info(`[QueueLess Migration] Applied successfully: ${file}`);
      } catch (err) {
        await client.query('ROLLBACK');
        console.error(`[QueueLess Migration] FAILED ${file}:`, err.message);
        throw err;
      }
    }

    console.info(`[QueueLess Migration] All ${isSeed ? 'seeds' : 'migrations'} completed.`);
  } finally {
    await client.end().catch(() => {});
  }
}

if (require.main === module) {
  runMigrations().catch(err => {
    console.error('[QueueLess Migration] Fatal error:', err);
    process.exit(1);
  });
}

module.exports = { runMigrations };
