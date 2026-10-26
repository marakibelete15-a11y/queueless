/**
 * @file Doctor Repository
 * Purpose: Direct database queries for doctor profiles, specialties, schedules, and active consultation status.
 * SRS Requirements: FR-1.1 (Doctor Profiles), FR-6.2 (Doctor Schedules)
 */

const db = require('../config/db');

async function listActiveDoctors(clinicId) {
  const result = await db.query(
    'SELECT id, name, specialty, room_number, is_active FROM doctors WHERE clinic_id = $1 AND is_active = true ORDER BY name ASC',
    [clinicId]
  );
  return result.rows;
}

module.exports = {
  listActiveDoctors,
};
