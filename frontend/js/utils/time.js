/**
 * @file Frontend Time Localization Utility
 * Purpose: Formats server UTC timestamps into Africa/Addis_Ababa wall-clock time for client UI displays.
 * SRS Requirements: SYS-TIME (UTC Storage Standard), BR-6 (Addis Ababa Display Standardization)
 */

export function formatAddisTime(isoString, options = {}) {
  if (!isoString) return '';
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Addis_Ababa',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    ...options,
  }).format(new Date(isoString));
}

export function formatAddisDate(isoString) {
  if (!isoString) return '';
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Addis_Ababa',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(isoString));
}
