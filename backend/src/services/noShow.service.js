/**
 * @file No-Show Service
 * Purpose: Evaluates called patients exceeding grace period thresholds, marks no-shows, and updates queue cascades.
 * SRS Requirements: FR-3.1 (No-Show Detection), BR-4 (No-Show Grace Period & Cascade Transitions)
 */

async function processNoShows(_clinicId) {
  // Placeholder: Sweeps entries where called_at exceeds NO_SHOW_GRACE_PERIOD_MINUTES
  return { processed: 0 };
}

module.exports = {
  processNoShows,
};
