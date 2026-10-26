/**
 * @file Staff User Repository
 * Purpose: Direct database queries for staff authentication, credentials, and role retrieval.
 * SRS Requirements: FR-4.1 (Staff Credentials), SEC-1 (Credential Persistence)
 */

const db = require('../config/db');

async function findUserByUsername(clinicId, username) {
  const result = await db.query(
    'SELECT id, clinic_id, username, password_hash, role, is_active FROM staff_users WHERE clinic_id = $1 AND username = $2 LIMIT 1',
    [clinicId, username]
  );
  return result.rows[0] || null;
}

module.exports = {
  findUserByUsername,
};
