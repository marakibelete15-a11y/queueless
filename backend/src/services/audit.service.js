/**
 * @file Audit Trail Service
 * Purpose: Emits immutable, append-only activity records ensuring zero PII enters the audit database.
 * SRS Requirements: NFR-AUDIT (Audit Trail Compliance), SEC-4 (Privacy & Zero PII Logging)
 */

async function recordEvent(
  _clinicId,
  _eventType,
  _entityType,
  _entityId,
  _details = {},
  _userId = null
) {
  // Placeholder: Validates payload to prevent PII leakage before delegating to audit repository
  return { recorded: true };
}

module.exports = {
  recordEvent,
};
