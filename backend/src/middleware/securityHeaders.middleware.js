/**
 * @file Security Headers Middleware
 * Purpose: Applies secure HTTP response headers (CSP, HSTS, frame-guard, XSS protection).
 * SRS Requirements: SEC-6 (HTTP Security Hardening)
 */

const helmet = require('helmet');

const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'"],
      imgSrc: ["'self'", 'data:'],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  crossOriginEmbedderPolicy: false,
});

module.exports = securityHeaders;
