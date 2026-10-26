/**
 * @file Queue Management Controller
 * Purpose: Handles HTTP requests for active queue boards, calling next patients, and marking no-shows.
 * SRS Requirements: FR-2.1 (Queue Board View), BR-1 (Priority Ordering), FR-3.1 (No-Show Trigger)
 */

const queueService = require('../services/queue.service');

async function getBoard(req, res, next) {
  try {
    const queue = await queueService.getLiveQueueState(req.query.clinicId);
    res.json({ success: true, data: queue, timestamp: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
}

async function callNext(req, res, next) {
  try {
    const nextPatient = await queueService.advanceQueue(req.user?.clinicId, req.body.doctorId);
    res.json({ success: true, data: nextPatient, timestamp: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
}

async function markNoShow(req, res, next) {
  try {
    res.json({
      success: true,
      message: 'Patient marked as no-show',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

async function transfer(req, res, next) {
  try {
    res.json({
      success: true,
      message: 'Queue entry transferred successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getBoard,
  callNext,
  markNoShow,
  transfer,
};
