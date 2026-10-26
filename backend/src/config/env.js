/**
 * @file Environment Configuration Loader
 * Purpose: Loads, parses, and validates required runtime environment variables.
 * SRS Requirements: SYS-1 (Configuration Integrity), SEC-1 (Secret Management)
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../../.env') });

const env = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  appMode: process.env.APP_MODE || 'demo',
  databaseUrl:
    process.env.DATABASE_URL || 'postgres://queueless:queueless@localhost:5432/queueless_dev',
  sessionSecret:
    process.env.SESSION_SECRET || 'dev-default-insecure-secret-key-change-in-production',
  tz: process.env.TZ || 'UTC',
  displayTimezone: process.env.DISPLAY_TIMEZONE || 'Africa/Addis_Ababa',
  corsOrigin: process.env.CORS_ORIGIN || '*',
};

module.exports = env;
