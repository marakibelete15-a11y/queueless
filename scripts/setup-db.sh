#!/usr/bin/env bash
set -euo pipefail

DB_NAME="${DB_NAME:-queueless_dev}"
DB_OWNER="${DB_OWNER:-queueless_owner}"
if [[ ! "$DB_NAME" =~ ^[a-z][a-z0-9_]*_dev$ ]]; then
  echo "DB_NAME must end in _dev; refusing setup." >&2; exit 2
fi
if [[ ! "$DB_OWNER" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "DB_OWNER must be a simple PostgreSQL role name." >&2; exit 2
fi
if [[ -z "${PG_ADMIN_URL:-}" ]]; then
  echo "Set PG_ADMIN_URL to an existing local PostgreSQL administrative connection." >&2; exit 2
fi
echo "Ensuring local development database ${DB_NAME} exists (existing databases are never dropped)."
psql "$PG_ADMIN_URL" -v ON_ERROR_STOP=1 -v db_name="$DB_NAME" -v db_owner="$DB_OWNER" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_owner')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name')
\gexec
SQL
echo "Database is ready. Configure DATABASE_URL in your local .env; roles and passwords are managed separately."
