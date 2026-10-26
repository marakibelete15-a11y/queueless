/**
 * @file Offline Outage Backfill Page Controller
 * Purpose: Allows reception staff to retrospectively batch-submit paper ledger records captured during power/network outages.
 * SRS Requirements: FR-5.1 (Outage Fallback & Backfill), OPS-2 (Outage Data Reconciliation)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';
import { qs, on } from '../utils/dom.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  const form = qs('#backfill-batch-form');
  on(form, 'submit', async e => {
    e.preventDefault();
    try {
      await apiRequest('/admin/backfill', {
        method: 'POST',
        body: { records: [] },
      });
    } catch (err) {
      console.error('Backfill submission failed:', err);
    }
  });
});
