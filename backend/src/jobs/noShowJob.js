/**
 * @file No-Show Periodic Sweep Job
 * Purpose: Periodically triggers the No-Show service to evaluate and mark expired called appointments.
 * SRS Requirements: FR-3.1 (Automated No-Show Detection), BR-4 (Grace Period Sweep)
 */

const noShowService = require('../services/noShow.service');

async function runNoShowSweep() {
  // Placeholder: Called periodically (e.g., every 60s) by system scheduler
  return noShowService.processNoShows('default-clinic-id');
}

module.exports = { runNoShowSweep };
