/**
 * @file CSRF Protection Middleware
 * Purpose: Validates anti-CSRF request headers on state-mutating requests from staff portals.
 * SRS Requirements: SEC-3 (Cross-Site Request Forgery Mitigation)
 */

function csrfProtection(req, res, next) {
  // Safe HTTP methods do not require CSRF token
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next();
  }

  const csrfToken = req.headers['x-csrf-token'];
  // Placeholder validation logic; to be expanded with signed session tokens
  if (process.env.NODE_ENV === 'production' && !csrfToken) {
    return res.status(403).json({
      success: false,
      error: { code: 'INVALID_CSRF_TOKEN', message: 'Missing or invalid CSRF token' },
      timestamp: new Date().toISOString(),
    });
  }

  next();
}

module.exports = { csrfProtection };
