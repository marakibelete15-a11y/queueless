# ADR 0002: PostgreSQL relational schema and SQL migration runner

- **Status:** Accepted for Phase 2 review
- **Date:** 2026-10-28

## Context

QueueLess needs a multi-clinic-ready persistence contract for appointments and shared doctor queues. The Phase 1 migration files were comments only; the referenced SRS PDF was not present in the available repository or attachments, so the schema is based on the detailed Phase 2 prompt and must be checked against the PDF before real-data approval.

## Decisions

- Use PostgreSQL, plain SQL and the existing `pg` dependency; keep the seven numbered files and add `008_request_deduplication.sql` for Phase 3 idempotency receipts.
- Keep `visit` as the sole owner of visit status and `queue_entry` as queue metadata. Use restrictive foreign keys, clinic-scoped composite references, partial unique indexes, and database triggers where identity must not be deleted or rewritten.
- Keep retention periods NULL until clinic/legal review. Include only synthetic fixtures and no demo login credentials.
- Track applied migration checksums in the separate `schema_migrations` table, execute each migration and history insert transactionally, serialize runners with a PostgreSQL advisory lock, and stop on modified/missing history.
- Use forward repair migrations for applied schema changes; do not promise automatic down migrations.

## Consequences

The database enforces relational/uniqueness invariants. Phone-based booking limits, authorization, transition policy, queue operation/idempotency semantics and settings cross-validation still need application transactions in Phase 3. PostgreSQL integration tests need a dedicated `_test` database and a running local server.
