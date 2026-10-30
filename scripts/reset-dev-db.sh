#!/usr/bin/env bash
set -euo pipefail
DB_NAME="${DB_NAME:-queueless_dev}"
DB_OWNER="${DB_OWNER:-queueless_owner}"
if [[ ! "$DB_NAME" =~ ^[a-z][a-z0-9_]*_dev$ ]]; then echo "Refusing reset: DB_NAME must end in _dev." >&2; exit 2; fi
if [[ -z "${PG_ADMIN_URL:-}" ]]; then echo "Set PG_ADMIN_URL to the local PostgreSQL admin connection." >&2; exit 2; fi
printf "This permanently deletes database %s. Type its exact name to continue: " "$DB_NAME"
read -r confirmation
if [[ "$confirmation" != "$DB_NAME" ]]; then echo "Confirmation did not match; no action taken."; exit 1; fi
dropdb --if-exists --maintenance-db "$PG_ADMIN_URL" "$DB_NAME"
createdb --maintenance-db "$PG_ADMIN_URL" --owner "$DB_OWNER" "$DB_NAME"
echo "Empty development database recreated. Run npm run migrate, then npm run seed with APP_MODE=demo."
