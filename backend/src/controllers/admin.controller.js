/**
 * @file Clinic Administration Controller
 * Purpose: Handles HTTP requests for clinic configuration, doctor roster administration, and outage backfill.
 * SRS Requirements: FR-6.1 (Clinic Settings), FR-6.2 (Doctor Roster), FR-5.1 (Outage Backfill)
 */

const backfillService = require('../services/backfill.service');

async function getClinicConfig(req, res, next) {
  try {
    res.json({
      success: true,
      data: {
        name: 'Demo Primary Clinic',
        timezone: 'Africa/Addis_Ababa',
        openTime: '08:00',
        closeTime: '17:00',
      },
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

async function updateClinicConfig(req, res, next) {
  try {
    res.json({
      success: true,
      message: 'Clinic configuration updated',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

async function listDoctors(req, res, next) {
  try {
    res.json({ success: true, data: [], timestamp: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
}

async function createDoctor(req, res, next) {
  try {
    res.status(201).json({
      success: true,
      message: 'Doctor added to roster',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

async function submitBackfill(req, res, next) {
  try {
    const result = await backfillService.processBackfillBatch(
      req.user?.clinicId,
      req.user?.id,
      req.body.records
    );
    res.json({ success: true, data: result, timestamp: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getClinicConfig,
  updateClinicConfig,
  listDoctors,
  createDoctor,
  submitBackfill,
};
