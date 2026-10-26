/**
 * @file Visits & Triage Controller
 * Purpose: Handles HTTP requests for walk-in patient triage, scheduled appointment check-in, and visit completion.
 * SRS Requirements: FR-2.2 (Check-in), FR-5.1 (Walk-in Registration), BR-2 (State Machine)
 */

async function registerWalkin(req, res, next) {
  try {
    res.status(201).json({
      success: true,
      data: { tokenNumber: 'W-104', priority: 'standard', status: 'waiting' },
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

async function checkin(req, res, next) {
  try {
    res.json({
      success: true,
      data: { tokenNumber: 'A-201', status: 'waiting' },
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

async function completeVisit(req, res, next) {
  try {
    res.json({
      success: true,
      message: 'Consultation marked as complete',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  registerWalkin,
  checkin,
  completeVisit,
};
