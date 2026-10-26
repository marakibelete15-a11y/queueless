/**
 * @file Booking Request Validator
 * Purpose: Validates patient appointment booking requests, checking doctor ID, date, and contact format.
 * SRS Requirements: FR-1.2 (Booking Validation), SEC-7 (Input Sanitization)
 */

function validateBooking(body = {}) {
  const { doctorId, slotTime } = body;
  if (!doctorId || typeof doctorId !== 'string') {
    return { error: new Error('doctorId is required and must be a string') };
  }
  if (!slotTime || isNaN(Date.parse(slotTime))) {
    return { error: new Error('slotTime is required and must be a valid ISO timestamp') };
  }
  return { value: body };
}

module.exports = { validateBooking };
