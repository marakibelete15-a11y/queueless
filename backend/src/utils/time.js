/**
 * @file Timezone & Timestamp Utility
 * Purpose: Ensures timestamps are persisted in UTC and localized to Africa/Addis_Ababa for display.
 * SRS Requirements: SYS-TIME (UTC Storage Standard), BR-6 (Addis Ababa Business Hours)
 */

const env = require('../config/env');

function nowUTC() {
  return new Date();
}

function toISOUTCString(date = new Date()) {
  return new Date(date).toISOString();
}

function formatDisplayTime(date, timeZone = env.displayTimezone) {
  return new Intl.DateTimeFormat('en-GB', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).format(new Date(date));
}

module.exports = {
  nowUTC,
  toISOUTCString,
  formatDisplayTime,
};
