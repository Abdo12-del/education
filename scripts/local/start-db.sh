#!/usr/bin/env bash
# ============================================================================
# Start the PORTABLE MySQL 5.7 instance that lives inside the project
# (local-db/data). Runs in the foreground under a supervisor — stop with
# SIGTERM. Bootstraps the data directory automatically on first run.
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB_DIR="$ROOT/local-db"
DIST="$DB_DIR/mysql57"

# First run? bootstrap the data directory automatically.
bash "$(dirname "${BASH_SOURCE[0]}")/init-db.sh"

export LD_LIBRARY_PATH="$DB_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
echo "[db] starting portable MySQL from $DB_DIR (port ${PORTABLE_DB_PORT:-3306})..."
exec "$DIST/mysqld" --defaults-file="$DB_DIR/my.cnf"
