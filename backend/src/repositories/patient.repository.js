/**
 * @file Patient Repository
 * Purpose: Direct database queries for pseudonymized patient records and contact verification hashes.
 * SRS Requirements: FR-1.2 (Patient Booking Records), SEC-4 (Patient Privacy & Pseudonymization)
 */

const db = require('../config/db');

async function findPatientByHash(clinicId, phoneHash) {
  const result = await db.query(
    'SELECT id, clinic_id, pseudo_identifier, phone_hash, created_at FROM patients WHERE clinic_id = $1 AND phone_hash = $2 LIMIT 1',
    [clinicId, phoneHash]
  );
  return result.rows[0] || null;
}

module.exports = {
  findPatientByHash,
};
