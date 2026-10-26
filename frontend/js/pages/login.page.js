/**
 * @file Staff Login Page Controller
 * Purpose: Handles staff credential submission, session cookie creation, and redirection to role dashboard.
 * SRS Requirements: FR-4.1 (Staff Login), SEC-1 (Credential Transport & Session Handshake)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';
import { qs, on } from '../utils/dom.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  const loginForm = qs('#staff-login-form');
  on(loginForm, 'submit', async e => {
    e.preventDefault();
    const username = qs('#username-input')?.value;
    const password = qs('#password-input')?.value;

    try {
      const res = await apiRequest('/auth/login', {
        method: 'POST',
        body: { username, password },
      });
      if (res.data?.user?.role === 'doctor') {
        window.location.href = '/staff/doctor.html';
      } else {
        window.location.href = '/staff/receptionist.html';
      }
    } catch (err) {
      console.error('Login error:', err);
    }
  });
});
