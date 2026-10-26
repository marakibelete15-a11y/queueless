/**
 * @file Express Application Bootstrap
 * Purpose: Configures middleware (security headers, body parsing, CORS), mounts /api/v1 routes and static frontend, and handles errors.
 * SRS Requirements: SYS-API (REST Architecture), SEC-6 (Security Headers), REL-3 (Health & Error Resilience)
 */

const express = require('express');
const path = require('path');
const cors = require('cors');
const securityHeaders = require('./middleware/securityHeaders.middleware');
const errorHandler = require('./middleware/errorHandler.middleware');
const apiRoutes = require('./routes/index');
const env = require('./config/env');

const app = express();

// Security and transport middleware
app.use(securityHeaders);
app.use(cors({ origin: env.corsOrigin, credentials: true }));

// Body parsing middleware
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Serve vanilla frontend static assets
const frontendDir = path.resolve(__dirname, '../../frontend');
app.use(express.static(frontendDir));
app.use(express.static(path.join(frontendDir, 'public')));

// Mount API v1 routes
app.use('/api/v1', apiRoutes);

// Centralized error handler
app.use(errorHandler);

module.exports = app;
