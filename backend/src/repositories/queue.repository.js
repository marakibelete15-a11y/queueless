/**
 * @file Queue Repository
 * Purpose: Direct database queries for active queue state, token ordering, and status updates.
 * SRS Requirements: FR-2.1 (Queue Management), BR-1 (Priority Ordering), SYS-PERF (Queue Ingestion Query)
 */

const db = require('../config/db');

async function getActiveQueue(clinicId, doctorId = null) {
  let query =
    "SELECT id, clinic_id, doctor_id, visit_id, token_number, priority, status, called_at, created_at FROM queue_entries WHERE clinic_id = $1 AND status IN ('waiting', 'called', 'in_consultation')";
  const params = [clinicId];

  if (doctorId) {
    params.push(doctorId);
    query += ` AND doctor_id = $${params.length}`;
  }

  query += ' ORDER BY priority DESC, created_at ASC';
  const result = await db.query(query, params);
  return result.rows;
}

module.exports = {
  getActiveQueue,
};
