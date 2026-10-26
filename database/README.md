# QueueLess Database Management

## Overview

QueueLess utilizes a direct, plain-SQL migration methodology managed with PostgreSQL and the `pg` client library.

## Directory Structure

- `migrations/`: Sequentially numbered SQL files executed in ascending order:
  - `001_clinic_settings.sql` (Clinic & Multi-tenant configuration)
  - `002_users_sessions.sql` (Staff accounts & RBAC sessions)
  - `003_doctors_schedules_slots.sql` (Roster & Appointment slots)
  - `004_patients_visits.sql` (Patient records & Visit lifecycle)
  - `005_queue_entries.sql` (Queue entries & Priority tracking)
  - `006_events_activity_log.sql` (Append-only audit trail)
  - `007_constraints_indexes.sql` (Integrity constraints & Performance indexes)
- `seeds/`: Synthetic demonstration records for local testing (`001_synthetic_seed.sql`).

## Migration Execution

To apply unapplied migrations:

```bash
npm run migrate
```

To load synthetic demo seed data:

```bash
npm run seed
```

To reset the local development database completely:

```bash
./scripts/reset-dev-db.sh
```

## Migration Conventions

1. Migrations are forward-only. Never modify an existing migration file once applied or committed to `develop`/`main`.
2. Add new migrations using the next sequential three-digit prefix (e.g., `008_feature_name.sql`).
3. Each migration runs within a single atomic database transaction.
