/**
 * @file Audit Log Repository
 * Purpose: Append-only database persistence for audit events and state transitions without PII.
 * SRS Requirements: NFR-AUDIT (Append-Only Event Ledger), SEC-4 (Audit Trail Persistence)
 */

const db = require('../config/db');

async function insertLog(clinicId, eventType, entityType, entityId, details = {}, userId = null) {
  const result = await db.query(
    `INSERT INTO activity_log (clinic_id, event_type, entity_type, entity_id, details_json, user_id, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, NOW())
     RETURNING id, created_at`,
    [clinicId, eventType, entityType, entityId, JSON.stringify(details), userId]
  );
  return result.rows[0];
}

module.exports = {
  insertLog,
};
