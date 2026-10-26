#!/usr/bin/env bash
# ==============================================================================
# Script: setup-db.sh
# Purpose: Creates the PostgreSQL database user and database if they do not exist.
# SRS Requirements: SYS-1 (Environment Provisioning), OPS-1 (Deployment Setup)
# ==============================================================================

set -euo pipefail

DB_NAME="${DB_NAME:-queueless_dev}"
DB_USER="${DB_USER:-queueless}"
DB_PASS="${DB_PASS:-queueless}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

echo "[QueueLess] Setting up database '${DB_NAME}' for user '${DB_USER}'..."

# Attempt to create user and database via psql
psql -h "${DB_HOST}" -p "${DB_PORT}" -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}'" | grep -q 1 || \
psql -h "${DB_HOST}" -p "${DB_PORT}" -U postgres -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

psql -h "${DB_HOST}" -p "${DB_PORT}" -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || \
psql -h "${DB_HOST}" -p "${DB_PORT}" -U postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

echo "[QueueLess] Database setup complete."
