#!/usr/bin/env bash
# ==============================================================================
# Script: reset-dev-db.sh
# Purpose: Drops and recreates the local development database for a clean state.
# SRS Requirements: DEV-RESET (Development Reset), OPS-1 (Maintenance)
# ==============================================================================

set -euo pipefail

DB_NAME="${DB_NAME:-queueless_dev}"
DB_USER="${DB_USER:-queueless}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

echo "[QueueLess] WARNING: Resetting development database '${DB_NAME}'..."

psql -h "${DB_HOST}" -p "${DB_PORT}" -U postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

echo "[QueueLess] Re-running migrations..."
"$(dirname "$0")/run-migrations.sh"

echo "[QueueLess] Development database reset complete."
