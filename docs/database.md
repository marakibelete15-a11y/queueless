# QueueLess Database Architecture & Conventions

## 1. Engine & Access Layer

- **Engine**: PostgreSQL 14+
- **Access Library**: Native `pg` (node-postgres) Connection Pool.
- **ORM Policy**: Strictly NO ORM (no Prisma, TypeORM, Sequelize). All queries are written in parameterized plain SQL to maximize predictability, performance, and transparency.

## 2. Multi-tenancy Rules

Although QueueLess operates for one clinic initially, multi-tenant preparedness is strictly enforced at the schema layer:

- Every clinic-owned table must include a non-nullable `clinic_id UUID REFERENCES clinics(id)`.
- All queries filtering clinic-scoped resources must explicitly enforce `WHERE clinic_id = $1`.

## 3. Timezone Guidelines

- **Storage Standard**: All timestamps must be stored as `TIMESTAMPTZ` in UTC (`+00:00`).
- **Display Standard**: Application layer converts UTC timestamps to `Africa/Addis_Ababa` for presentation and business day calculation.
- **Clinic Operating Hours**: Stored as localized wall-clock times (e.g., `08:00:00` to `17:00:00`) alongside the clinic's configured timezone.

## 4. Migration Conventions

Numbered migration files reside in `database/migrations/`:

- `001_clinic_settings.sql`
- `002_users_sessions.sql`
- `003_doctors_schedules_slots.sql`
- `004_patients_visits.sql`
- `005_queue_entries.sql`
- `006_events_activity_log.sql`
- `007_constraints_indexes.sql`

Migrations are executed sequentially and recorded in the `schema_migrations` table inside an atomic transaction.
Rollback scripts or forward-only fix scripts are created with succeeding sequence numbers.

## 5. Audit Logging Principles

- The `activity_log` table is append-only. No `UPDATE` or `DELETE` grants should be issued to the application user on this table.
- Log entries record event types (`APPOINTMENT_BOOKED`, `PATIENT_CALLED`, `NO_SHOW_MARKED`), timestamps in UTC, user/session IDs, and anonymized reference keys.
- **Zero PII**: Patient names, national IDs, and contact numbers must never appear in `activity_log.details_json`.
