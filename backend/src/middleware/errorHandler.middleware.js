/**
 * @file Centralized Error Handling Middleware
 * Purpose: Formats uncaught application errors into safe JSON responses without leaking stack traces.
 * SRS Requirements: REL-3 (Fault Tolerance), SYS-ERR (Uniform Error Envelopes)
 */

const logger = require('../utils/logger');
const env = require('../config/env');

function errorHandler(err, req, res, _next) {
  const statusCode = err.statusCode || 500;
  const errorCode = err.code || 'INTERNAL_SERVER_ERROR';
  const message =
    statusCode === 500 && env.nodeEnv === 'production'
      ? 'An unexpected internal error occurred.'
      : err.message || 'An unexpected error occurred.';

  logger.error(`[Error] ${req.method} ${req.originalUrl}: ${err.message}`, {
    code: errorCode,
    statusCode,
  });

  res.status(statusCode).json({
    success: false,
    error: {
      code: errorCode,
      message,
    },
    timestamp: new Date().toISOString(),
  });
}

module.exports = errorHandler;
