/**
 * @file API Client Module
 * Purpose: Vanilla fetch wrapper handling REST requests, JSON envelopes, CSRF headers, and error parsing.
 * SRS Requirements: SYS-API (Client-Server REST Integration), SEC-3 (Automatic CSRF Token Header Injection)
 */

const BASE_URL = '/api/v1';

export async function apiRequest(endpoint, { method = 'GET', body = null, headers = {} } = {}) {
  const requestHeaders = {
    'Content-Type': 'application/json',
    ...headers,
  };

  // Attach anti-CSRF token from cookie/meta if present on mutating requests
  if (!['GET', 'HEAD', 'OPTIONS'].includes(method.toUpperCase())) {
    const metaToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
    if (metaToken) {
      requestHeaders['X-CSRF-Token'] = metaToken;
    }
  }

  const options = {
    method,
    headers: requestHeaders,
    credentials: 'same-origin',
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(`${BASE_URL}${endpoint}`, options);
  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    const error = new Error(data?.error?.message || `HTTP error ${response.status}`);
    error.status = response.status;
    error.code = data?.error?.code || 'UNKNOWN_ERROR';
    throw error;
  }

  return data;
}
