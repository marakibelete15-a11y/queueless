/**
 * @file System Constants
 * Purpose: Centralizes application roles, queue statuses, visit states, and business thresholds.
 * SRS Requirements: BR-1 (Priority Matrix), BR-2 (State Machine), SEC-2 (RBAC Roles)
 */

module.exports = {
  ROLES: {
    ADMIN: 'admin',
    DOCTOR: 'doctor',
    RECEPTIONIST: 'receptionist',
  },
  QUEUE_STATUS: {
    WAITING: 'waiting',
    CALLED: 'called',
    IN_CONSULTATION: 'in_consultation',
    COMPLETED: 'completed',
    NO_SHOW: 'no_show',
    CANCELLED: 'cancelled',
  },
  VISIT_TYPE: {
    SCHEDULED: 'scheduled',
    WALKIN: 'walkin',
  },
  DEFAULT_SLOT_DURATION_MINUTES: 15,
  NO_SHOW_GRACE_PERIOD_MINUTES: 10,
};
