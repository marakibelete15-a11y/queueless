/**
 * @file Booking Reference Utility
 * Purpose: Generates unambiguous, non-sequential alphanumeric reference codes for patient bookings.
 * SRS Requirements: FR-1.3 (Booking Confirmation), SEC-4 (Non-guessable Public References)
 */

const crypto = require('crypto');

function generateBookingReference() {
  const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let ref = 'QL-';
  const bytes = crypto.randomBytes(6);
  for (let i = 0; i < 6; i++) {
    ref += characters[bytes[i] % characters.length];
  }
  return ref;
}

module.exports = {
  generateBookingReference,
};
