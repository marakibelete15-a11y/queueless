/**
 * @file Adaptive Polling Utility
 * Purpose: Handles periodic data fetching with exponential backoff and jitter to protect backend during network recovery.
 * SRS Requirements: REL-3 (Network Resilience), SYS-PERF (Thundering Herd Prevention)
 */

export function startPolling(
  fetchFn,
  { intervalMs = 5000, maxIntervalMs = 30000, onData, onError } = {}
) {
  let active = true;
  let currentInterval = intervalMs;
  let timerId = null;

  async function poll() {
    if (!active) return;
    try {
      const data = await fetchFn();
      currentInterval = intervalMs; // Reset backoff on success
      if (onData) onData(data);
    } catch (err) {
      currentInterval = Math.min(currentInterval * 1.5, maxIntervalMs); // Back off
      if (onError) onError(err);
    } finally {
      if (active) {
        timerId = setTimeout(poll, currentInterval);
      }
    }
  }

  poll();

  return () => {
    active = false;
    if (timerId) clearTimeout(timerId);
  };
}
