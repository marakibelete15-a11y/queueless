# Database development

Read [the database design and operating contract](../docs/database.md) before changing SQL. PostgreSQL + plain SQL + `pg` are the only database tools; there is no ORM or container requirement.

## Local setup

Create dedicated local roles/databases through your PostgreSQL administrator. Keep migration ownership separate from application access and set passwords interactively rather than in shell history:

```sql
CREATE ROLE queueless_owner LOGIN;
\password queueless_owner
CREATE ROLE queueless_app LOGIN;
\password queueless_app
```

Create the database without dropping existing data:

```bash
PG_ADMIN_URL='postgresql://local-admin@localhost/postgres' npm run db:setup
```

The admin URL is supplied in your shell, not committed. The setup script creates `queueless_dev` only if it does not exist and expects an existing `queueless_owner` role. A separate `queueless_test` database should be created for automated database tests. Follow the least-privilege recipe in `docs/database.md` to grant only the application permissions needed. Do not grant superuser.

Copy `.env.example` to `.env`. Set `DATABASE_URL` to the app login and `MIGRATION_DATABASE_URL` to the owner login; replace all placeholders and never commit `.env`:

```bash
npm run migrate
APP_MODE=demo npm run seed
```

To run integration tests, point `MIGRATION_DATABASE_URL` to the dedicated `queueless_test` database, then run `npm run test:db`. The test runner checks the database name ends in `_test` and executes actual PostgreSQL migrations/constraints. Tests were not executable in this environment because `pg_isready` reported no local server.

## Files and change rules

- `migrations/001`–`008`: ordered schema and integrity changes.
- `seeds/001_synthetic_seed.sql`: repeatable fictional clinic fixtures, no login credentials, no retention values.
- `schema_migrations`: created by the runner and kept separate from business tables; includes version and SHA-256.

Applied migrations are immutable. Add a new three-digit migration after the latest shared version, coordinate naming with the API team, review clinic scoping and referential actions, then add database tests and update `docs/database.md`. The runner serializes concurrent migrations, wraps every file and its history insertion in one transaction, and refuses changed or missing applied files. See the design doc for forward repair and backup-based recovery.

`npm run db:reset-dev` drops only a database ending in `_dev`, after you type its full name, then recreates it empty. It needs `PG_ADMIN_URL` and `DB_OWNER`; it does not run migrations, seed, or touch the test DB automatically.
