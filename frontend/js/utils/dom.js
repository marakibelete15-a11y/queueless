/**
 * @file DOM Helper Utilities
 * Purpose: Provides safe element selectors, event listeners, and dynamic template rendering utilities.
 * SRS Requirements: UI-1 (Accessibility & Clean DOM Updates)
 */

export function qs(selector, parent = document) {
  return parent.querySelector(selector);
}

export function qsa(selector, parent = document) {
  return Array.from(parent.querySelectorAll(selector));
}

export function on(element, event, handler) {
  if (element) {
    element.addEventListener(event, handler);
  }
}
