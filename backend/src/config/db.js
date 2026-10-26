/**
 * @file Database Connection Pool
 * Purpose: Manages PostgreSQL connection pooling via the pg library with graceful teardown.
 * SRS Requirements: SYS-1 (Database Connectivity), SYS-PERF (Connection Pooling)
 */

const { Pool } = require('pg');
const env = require('./env');

const pool = new Pool({
  connectionString: env.databaseUrl,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
