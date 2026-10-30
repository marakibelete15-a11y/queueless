# QueueLess database development

PostgreSQL, plain SQL and the existing custom `pg` migration runner are used. No Docker or ORM is required. See [the complete schema contract](../docs/database.md) and [retention policy](retention.md).

## Local setup

Use an existing local PostgreSQL server. Provision a dedicated `queueless_owner` migration login and `queueless_app` login, then create `queueless_dev` and (if needed) `queueless_test`. Set role passwords interactively with `psql` `\password`; never put them in SQL or shell history. Use `database/roles/roles-and-grants.sql` as a database administrator after applying migrations. The application role receives DML only, while migrations run through `MIGRATION_DATABASE_URL` as the owner.

Set the two connection variables in your environment or an untracked `.env` file:

```bash
MIGRATION_DATABASE_URL='postgresql://queueless_owner@localhost/queueless_dev' npm run migrate
APP_MODE=demo MIGRATION_DATABASE_URL='postgresql://queueless_owner@localhost/queueless_dev' npm run seed
APP_MODE=demo MIGRATION_DATABASE_URL='postgresql://queueless_owner@localhost/queueless_dev' npm run seed:large
```

The runner applies migration files lexically in one transaction each and stores a SHA-256 checksum. It refuses missing or changed applied migrations. Each migration contains UP and DOWN sections; `npm run migrate:down` rolls back the latest applied file. Seeds are repeatable and are accepted only for a local database whose name ends in `_dev` with `APP_MODE=demo`. The large seed adds synthetic volume for planner inspection. Small fixtures use invented names, fake phone numbers and bcrypt cost-12 development passwords (`QueueLessDemo2026!`). Do not use these credentials outside a local demo.

`npm run db:setup` creates a missing development database only; it does not run migrations, grant roles, or modify an existing DB. `npm run db:reset-dev` is destructive, targets only a named `_dev` database, and requires typing the exact database name. For database integration tests, configure a separate `_test` database and run `npm run test:db`; never use development or production data.

## Files

- `migrations/001`–`008`: schema, constraints, indexes, and their DOWN sections.
- `seeds/001_synthetic_seed.sql`: small fictional frontend fixture.
- `seeds/002_large_explain_seed.sql`: 20,000-visit/10-doctor synthetic planner fixture.
- `queries/explain-dashboard.sql`: eight dashboard query plans using `EXPLAIN (ANALYZE, BUFFERS)`.
- `roles/roles-and-grants.sql`: database administrator provisioning, role separation and least-privilege grants.

## Development only

Synthetic seed data and its development credentials are for local development only. Retention is unset pending legal review; never fill in guessed periods. Follow the explicit administrator approval workflow in [retention.md](retention.md) before any retention deletion.
