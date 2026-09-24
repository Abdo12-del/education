#!/usr/bin/env bash
# ============================================================================
# Start the Frappe dev server for the Madrasati bench (foreground).
# Requires: scripts/local/start-db.sh running + setup-site.sh completed.
# Serves on 0.0.0.0:8000 (gunicorn-style dev server via `bench start`).
# ============================================================================
set -euo pipefail

export PATH="$HOME/.local/node24/bin:$HOME/.local/bin:$PATH"
cd "$HOME/frappe-bench"

SITE="${SITE:-$(cat sites/currentsite.txt 2>/dev/null || true)}"
echo "[bench] site: ${SITE:-<default>}"
echo "[bench] redis: $(redis-cli -h 127.0.0.1 ping 2>/dev/null || echo DOWN)"
echo "[bench] db: $(mariadb --host 127.0.0.1 --port "${PORTABLE_DB_PORT:-3306}" -u root -p"${PORTABLE_DB_ROOT_PASSWORD:-root}" -e 'SELECT 1' >/dev/null 2>&1 && echo OK || echo DOWN)"

exec bench start
