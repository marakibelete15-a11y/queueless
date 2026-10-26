/**
 * @file Staff Authentication Controller
 * Purpose: Handles HTTP requests for staff authentication, session cookie issuance, and current session inspection.
 * SRS Requirements: FR-4.1 (Staff Login), SEC-1 (Credential & Session Management)
 */

const authService = require('../services/auth.service');

async function login(req, res, next) {
  try {
    const { username, password } = req.body;
    const session = await authService.loginStaff(username, password);
    res.json({ success: true, data: session, timestamp: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
}

async function logout(req, res, next) {
  try {
    res.json({
      success: true,
      message: 'Logged out successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

async function me(req, res, next) {
  try {
    res.json({ success: true, data: req.user || null, timestamp: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  login,
  logout,
  me,
};
