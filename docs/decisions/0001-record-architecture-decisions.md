# ADR 0001: Architecture Decisions and Core Technical Stack

## Status

Accepted

## Context

QueueLess requires a resilient, maintainable, and low-complexity software foundation suitable for single-clinic deployment with multi-tenant readiness. Constraints include zero frontend frameworks, zero build step, no Docker containers, strict UTC database storage, layered backend separation, and vanilla ES modules.

## Decisions

### 1. Plain SQL Migrations vs ORM

- **Decision**: Use plain numbered `.sql` migration files executed via a custom script (`scripts/run-migrations.sh`) using the native `pg` client, rather than an ORM or heavyweight migration framework.
- **Rationale**: Plain SQL keeps query execution completely predictable, minimizes external dependencies, and eliminates ORM abstraction leaks in healthcare queue scheduling.

### 2. Native Vanilla Frontend with ES Modules

- **Decision**: Avoid React/Vue/Angular and bundlers (Vite/Webpack). Serve native HTML5, CSS3, and ES modules (`<script type="module">`).
- **Rationale**: Zero compilation latency, immediate deployability, and complete browser independence without external CDNs or analytics trackers.

### 3. Layered Backend Separation

- **Decision**: Enforce unidirectional layering: Routes -> Controllers -> Services -> Repositories.
- **Rationale**: Keeps business rules (dynamic ETAs, queue priority calculations, No-Show thresholds) decoupled from transport protocols (HTTP/REST) and persistence mechanics.

## Consequences

- Developers write raw SQL queries using parameterized statements to prevent SQL injection.
- Frontend scripts require explicit `.js` extensions in import paths.
- All timestamps must be explicitly passed through conversion utilities between UTC and `Africa/Addis_Ababa`.
