/**
 * @file API Router Index
 * Purpose: Mounts all versioned REST sub-routers under the /api/v1 namespace and defines the health probe.
 * SRS Requirements: SYS-API (REST API Versioning), REL-3 (Health Check Probe)
 */

const express = require('express');
const publicRoutes = require('./public.routes');
const authRoutes = require('./auth.routes');
const queueRoutes = require('./queue.routes');
const visitsRoutes = require('./visits.routes');
const adminRoutes = require('./admin.routes');
const reportsRoutes = require('./reports.routes');
const { formatDisplayTime, toISOUTCString } = require('../utils/time');
const env = require('../config/env');

const router = express.Router();

// Liveness & Readiness health check probe
router.get('/health', (_req, res) => {
  const now = new Date();
  res.json({
    status: 'ok',
    timestamp: toISOUTCString(now),
    displayTime: formatDisplayTime(now),
    timezone: env.displayTimezone,
    mode: env.appMode,
  });
});

// Sub-router mount points
router.use('/public', publicRoutes);
router.use('/auth', authRoutes);
router.use('/queue', queueRoutes);
router.use('/visits', visitsRoutes);
router.use('/admin', adminRoutes);
router.use('/reports', reportsRoutes);

module.exports = router;
