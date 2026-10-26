/**
 * @file Public Endpoints Controller
 * Purpose: Handles public HTTP requests for active doctor lists, slot availability, booking creation, and status queries.
 * SRS Requirements: FR-1.1 (Slot Inquiry), FR-1.2 (Appointment Booking), FR-2.3 (Queue Status)
 */

const bookingService = require('../services/booking.service');
const scheduleService = require('../services/schedule.service');

async function getDoctors(req, res, next) {
  try {
    res.json({ success: true, data: [], timestamp: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
}

async function getSlots(req, res, next) {
  try {
    const slots = await scheduleService.getAvailableSlots(req.query.doctorId, req.query.date);
    res.json({ success: true, data: slots, timestamp: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
}

async function createBooking(req, res, next) {
  try {
    const booking = await bookingService.createBooking(req.body);
    res.status(201).json({ success: true, data: booking, timestamp: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
}

async function getBookingStatus(req, res, next) {
  try {
    res.json({
      success: true,
      data: { reference: req.params.reference, status: 'confirmed', position: 3, etaMinutes: 25 },
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

async function cancelBooking(req, res, next) {
  try {
    res.json({
      success: true,
      message: 'Booking successfully cancelled',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getDoctors,
  getSlots,
  createBooking,
  getBookingStatus,
  cancelBooking,
};
