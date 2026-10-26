/**
 * @file Integration Test: Health Check Endpoint
 * Purpose: Verifies the /api/v1/health probe returns 200 OK with UTC timestamp and Addis Ababa timezone.
 * SRS Requirements: SYS-API (REST Health Endpoint), REL-3 (Liveness/Readiness Probe)
 */

const request = require('supertest');
const app = require('../../src/app');

describe('GET /api/v1/health', () => {
  test('returns 200 OK with operational status, UTC timestamp, and Africa/Addis_Ababa timezone', async () => {
    const response = await request(app)
      .get('/api/v1/health')
      .expect('Content-Type', /json/)
      .expect(200);

    expect(response.body).toHaveProperty('status', 'ok');
    expect(response.body).toHaveProperty('timestamp');
    expect(response.body).toHaveProperty('displayTime');
    expect(response.body).toHaveProperty('timezone', 'Africa/Addis_Ababa');
    expect(response.body).toHaveProperty('mode');
  });
});
