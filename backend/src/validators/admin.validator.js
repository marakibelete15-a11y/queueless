/**
 * @file Admin Configuration Validator
 * Purpose: Validates clinic settings, operating hour adjustments, and doctor roster additions.
 * SRS Requirements: FR-6.1 (Clinic Configuration), FR-6.2 (Doctor Administration)
 */

function validateClinicConfig(body = {}) {
  const { name, openTime, closeTime } = body;
  if (!name || typeof name !== 'string') {
    return { error: new Error('Clinic name is required') };
  }
  if (!openTime || !closeTime) {
    return { error: new Error('Both openTime and closeTime are required') };
  }
  return { value: body };
}

module.exports = { validateClinicConfig };
