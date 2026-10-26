/**
 * @file Visit Repository
 * Purpose: Direct database queries for appointments, walk-in visits, and consultation durations.
 * SRS Requirements: FR-1.2 (Appointment Visits), FR-2.2 (Check-in Status), FR-5.1 (Walk-in Intake)
 */

const db = require('../config/db');

async function findVisitByReference(clinicId, bookingRef) {
  const result = await db.query(
    'SELECT id, clinic_id, booking_reference, doctor_id, patient_id, visit_type, status, scheduled_at FROM visits WHERE clinic_id = $1 AND booking_reference = $2 LIMIT 1',
    [clinicId, bookingRef]
  );
  return result.rows[0] || null;
}

module.exports = {
  findVisitByReference,
};
