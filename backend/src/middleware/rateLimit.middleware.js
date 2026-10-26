/**
 * @file Sliding-Window Rate Limiting Middleware
 * Purpose: Prevents brute force and API abuse by rate limiting requests per client IP.
 * SRS Requirements: SEC-5 (Public API Abuse Prevention), REL-1 (DDoS Mitigation)
 */

const ipRequests = new Map();

function rateLimit({ windowMs = 60000, max = 60 } = {}) {
  return (req, res, next) => {
    const ip = req.ip || req.connection.remoteAddress || 'unknown';
    const now = Date.now();

    const record = ipRequests.get(ip) || { count: 0, resetAt: now + windowMs };

    if (now > record.resetAt) {
      record.count = 1;
      record.resetAt = now + windowMs;
    } else {
      record.count += 1;
    }

    ipRequests.set(ip, record);

    if (record.count > max) {
      return res.status(429).json({
        success: false,
        error: {
          code: 'TOO_MANY_REQUESTS',
          message: 'Rate limit exceeded. Please try again later.',
        },
        timestamp: new Date().toISOString(),
      });
    }

    next();
  };
}

module.exports = { rateLimit };
