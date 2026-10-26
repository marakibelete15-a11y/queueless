#!/usr/bin/env bash
# ==============================================================================
# Script: run-migrations.sh
# Purpose: Executes SQL schema migrations sequentially using the migration runner.
# SRS Requirements: SYS-1 (Database Versioning), OPS-1 (Deployment Automation)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "[QueueLess] Initiating database migration check..."
node "$SCRIPT_DIR/migrate.js" "$@"
