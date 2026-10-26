/**
 * @file Structured Application Logger
 * Purpose: Provides structured JSON logging while stripping PII (names, phones, emails) to preserve privacy.
 * SRS Requirements: NFR-LOGGING (Audit Readiness), SEC-4 (Zero PII in Application Logs)
 */

function sanitize(data) {
  if (typeof data !== 'object' || data === null) {
    return data;
  }
  const clean = Array.isArray(data) ? [] : {};
  const sensitiveKeys = ['name', 'phone', 'email', 'password', 'token', 'authorization', 'secret'];

  for (const [key, value] of Object.entries(data)) {
    if (sensitiveKeys.some(s => key.toLowerCase().includes(s))) {
      clean[key] = '[REDACTED]';
    } else if (typeof value === 'object' && value !== null) {
      clean[key] = sanitize(value);
    } else {
      clean[key] = value;
    }
  }
  return clean;
}

const logger = {
  info: (message, meta = {}) => {
    console.info(
      JSON.stringify({
        level: 'INFO',
        message,
        meta: sanitize(meta),
        timestamp: new Date().toISOString(),
      })
    );
  },
  warn: (message, meta = {}) => {
    console.warn(
      JSON.stringify({
        level: 'WARN',
        message,
        meta: sanitize(meta),
        timestamp: new Date().toISOString(),
      })
    );
  },
  error: (message, meta = {}) => {
    console.error(
      JSON.stringify({
        level: 'ERROR',
        message,
        meta: sanitize(meta),
        timestamp: new Date().toISOString(),
      })
    );
  },
};

module.exports = logger;
