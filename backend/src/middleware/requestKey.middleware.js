/**
 * @file Idempotency Request Key Middleware
 * Purpose: Ensures duplicate POST requests (e.g. double appointment booking clicks) return cached results.
 * SRS Requirements: FR-1.4 (Idempotent Booking Requests), REL-1 (Duplicate Prevention)
 */

const seenKeys = new Map();

function requireRequestKey(req, res, next) {
  const idempotencyKey = req.headers['idempotency-key'];

  if (!idempotencyKey) {
    return next();
  }

  if (seenKeys.has(idempotencyKey)) {
    const cachedResponse = seenKeys.get(idempotencyKey);
    return res.status(cachedResponse.status).json(cachedResponse.body);
  }

  // Hook into response to cache upon completion
  const originalJson = res.json.bind(res);
  res.json = body => {
    seenKeys.set(idempotencyKey, { status: res.statusCode, body });
    return originalJson(body);
  };

  next();
}

module.exports = { requireRequestKey };
