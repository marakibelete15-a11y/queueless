/**
 * @file Visit Action Request Validator
 * Purpose: Validates patient check-in and walk-in triage registration requests.
 * SRS Requirements: FR-2.2 (Check-in Validation), FR-5.1 (Walk-in Intake Validation)
 */

function validateWalkin(body = {}) {
  const { doctorId, priority } = body;
  if (!doctorId || typeof doctorId !== 'string') {
    return { error: new Error('doctorId is required') };
  }
  if (priority && !['standard', 'urgent', 'emergency'].includes(priority)) {
    return { error: new Error('priority must be standard, urgent, or emergency') };
  }
  return { value: body };
}

module.exports = { validateWalkin };
