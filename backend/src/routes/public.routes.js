/**
 * @file Public API Routes
 * Purpose: Declares unauthenticated public endpoints for booking, slot lookup, and live queue status.
 * SRS Requirements: FR-1.1 (Slot Query), FR-1.2 (Appointment Booking), FR-2.3 (Queue Status), SEC-5 (Rate Limiting)
 */

const express = require('express');
const publicController = require('../controllers/public.controller');
const { rateLimit } = require('../middleware/rateLimit.middleware');
const { requireRequestKey } = require('../middleware/requestKey.middleware');
const { validate } = require('../middleware/validate.middleware');
const { validateBooking } = require('../validators/booking.validator');

const router = express.Router();

router.get('/doctors', rateLimit({ max: 120 }), publicController.getDoctors);
router.get('/slots', rateLimit({ max: 120 }), publicController.getSlots);
router.post(
  '/bookings',
  rateLimit({ max: 30 }),
  requireRequestKey,
  validate(validateBooking),
  publicController.createBooking
);
router.get('/status/:reference', rateLimit({ max: 60 }), publicController.getBookingStatus);
router.post('/cancel', rateLimit({ max: 20 }), publicController.cancelBooking);

module.exports = router;
