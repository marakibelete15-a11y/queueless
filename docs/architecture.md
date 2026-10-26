# QueueLess System Architecture

## 1. Overview

QueueLess is built around a clean, layered backend architecture paired with an ultra-lightweight vanilla web frontend. The design prioritizes maintainability, zero-build simplicity, strict data protection, and operational resilience.

## 2. Layered Backend Design

Data flows unidirectionally across clearly demarcated architectural layers:

```
[ HTTP Request ]
       │
       ▼
┌──────────────┐
│  Middleware  │  Auth/Session, RBAC, Rate Limiting, CSRF, Idempotency, Security Headers
└──────┬───────┘
       │
       ▼
┌──────────────┐
│    Routes    │  Defines endpoints and maps HTTP methods to controller actions
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Controllers  │  Validates input, extracts parameters, coordinates response status/codes
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Services   │  CORE BUSINESS LOGIC: Queue ordering, No-Show logic, ETA calculation
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Repositories │  Direct SQL queries via pg client, transactions, persistence
└──────┬───────┘
       │
       ▼
 [ PostgreSQL ]
```

### Architectural Principles:

1. **Business Logic Isolation**: Routes and controllers must NEVER calculate queue priority, determine No-Show transitions, or calculate wait times. All domain logic resides in `backend/src/services/`.
2. **Deny-by-Default RBAC**: Every administrative or staff route requires explicit role authorization.
3. **Audit Trails**: Critical state mutations emit append-only events to the activity log without containing PII.
4. **Idempotency**: All payment, booking, and check-in mutations accept an `Idempotency-Key` or unique client token handled by `requestKey.middleware.js`.

## 3. Frontend Architecture

- **Vanilla Modern JavaScript**: Utilizes ES modules (`import`/`export`) directly in modern browsers without webpack, Vite, Babel, or bundling tools.
- **Strict Separation of Presentation and Locales**: HTML templates load localized strings through `frontend/js/i18n/i18n.js` matching user locale preferences (`en`, `am`, `om`).
- **Resilient Real-time Polling**: Public queue boards and status trackers use adaptive backoff polling (`frontend/js/utils/polling.js`) to prevent thundering herd problems during network reconnection.
