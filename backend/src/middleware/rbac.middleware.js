/**
 * @file Role-Based Access Control (RBAC) Middleware
 * Purpose: Enforces strict deny-by-default authorization based on authenticated staff roles.
 * SRS Requirements: SEC-2 (Deny-by-Default Access Control), FR-4.2 (Role Authorization)
 */

function requireRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !req.user.role) {
      return res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: 'Access denied: no role assigned' },
        timestamp: new Date().toISOString(),
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: 'Access denied: insufficient permissions' },
        timestamp: new Date().toISOString(),
      });
    }

    next();
  };
}

module.exports = { requireRoles };
