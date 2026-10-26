/**
 * @file Staff Auth Request Validator
 * Purpose: Validates staff login credentials format and password complexity constraints.
 * SRS Requirements: FR-4.1 (Staff Login Validation), SEC-1 (Credential Constraints)
 */

function validateLogin(body = {}) {
  const { username, password } = body;
  if (!username || typeof username !== 'string' || username.trim().length === 0) {
    return { error: new Error('username is required') };
  }
  if (!password || typeof password !== 'string' || password.length < 8) {
    return { error: new Error('password is required and must be at least 8 characters') };
  }
  return { value: { username: username.trim(), password } };
}

module.exports = { validateLogin };
