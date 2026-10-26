/**
 * @file Unit Test: Timezone Utilities
 * Purpose: Verifies UTC timestamp formatting and Africa/Addis_Ababa presentation conversion.
 * SRS Requirements: SYS-TIME (UTC Storage Standard), BR-6 (Addis Ababa Business Hours)
 */

const { toISOUTCString, formatDisplayTime } = require('../../src/utils/time');

describe('Time Utilities', () => {
  test('toISOUTCString produces valid ISO 8601 UTC timestamp', () => {
    const date = new Date('2026-10-26T20:15:00.000Z');
    const result = toISOUTCString(date);
    expect(result).toBe('2026-10-26T20:15:00.000Z');
  });

  test('formatDisplayTime converts UTC timestamp to Africa/Addis_Ababa wall-clock string', () => {
    // 20:15 UTC is 23:15 in UTC+3 (Africa/Addis_Ababa)
    const date = new Date('2026-10-26T20:15:00.000Z');
    const formatted = formatDisplayTime(date, 'Africa/Addis_Ababa');
    expect(formatted).toContain('23:15:00');
    expect(formatted).toContain('26/10/2026');
  });
});
