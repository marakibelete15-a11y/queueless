/**
 * @file Session Authentication Middleware
 * Purpose: Validates staff session cookies and attaches authenticated user context to the request.
 * SRS Requirements: FR-4.1 (Staff Login), SEC-1 (Session Integrity)
 */

function requireAuth(req, res, next) {
  // Placeholder: Session verification logic to be connected with session repository
  const sessionToken = req.headers['authorization'] || req.cookies?.['ql_session'];

  if (!sessionToken) {
    return res.status(401).json({
      success: false,
      error: { code: 'UNAUTHORIZED', message: 'Authentication required' },
      timestamp: new Date().toISOString(),
    });
  }

  // Placeholder: Attach mocked staff context for scaffold verification
  req.user = {
    id: '00000000-0000-0000-0000-000000000001',
    role: 'receptionist',
    clinicId: '00000000-0000-0000-0000-000000000000',
  };
  next();
}

module.exports = { requireAuth };
