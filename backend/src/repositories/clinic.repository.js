/**
 * @file Clinic Repository
 * Purpose: Direct database operations for clinic settings, hours, and multi-tenant metadata.
 * SRS Requirements: FR-6.1 (Clinic Management), SYS-1 (Multi-Tenancy Readiness)
 */

const db = require('../config/db');

async function getClinicById(clinicId) {
  const result = await db.query(
    'SELECT id, name, timezone, open_time, close_time FROM clinics WHERE id = $1 LIMIT 1',
    [clinicId]
  );
  return result.rows[0] || null;
}

module.exports = {
  getClinicById,
};
