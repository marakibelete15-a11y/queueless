/**
 * @file HTTP Server Entry Point
 * Purpose: Binds the Express application to network port and manages graceful shutdown on POSIX signals.
 * SRS Requirements: SYS-1 (Process Management), REL-3 (Graceful Process Teardown)
 */

const app = require('./app');
const env = require('./config/env');
const logger = require('./utils/logger');
const { pool } = require('./config/db');

const server = app.listen(env.port, () => {
  logger.info(
    `QueueLess server running on port ${env.port} [env=${env.nodeEnv}, mode=${env.appMode}]`
  );
});

function gracefulShutdown(signal) {
  logger.info(`Received ${signal}. Initiating graceful shutdown...`);
  server.close(async () => {
    logger.info('HTTP server closed. Closing database connection pool...');
    await pool.end().catch(() => {});
    logger.info('Cleanup complete. Exiting process.');
    process.exit(0);
  });
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
