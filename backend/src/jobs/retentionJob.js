/**
 * @file Scheduled Data Retention Job
 * Purpose: Periodically triggers the retention service to purge records past statutory retention limits.
 * SRS Requirements: NFR-RETENTION (Automated Purging), COMP-1 (Compliance)
 */

const retentionService = require('../services/retention.service');

async function runRetentionSweep() {
  // Placeholder: Runs weekly or monthly off-peak
  return retentionService.purgeExpiredRecords();
}

module.exports = { runRetentionSweep };
