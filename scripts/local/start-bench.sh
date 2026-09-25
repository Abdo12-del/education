#!/usr/bin/env bash
# ============================================================================
# Start the Frappe dev server for the Madrasati bench (foreground).
# Requires: scripts/local/start-db.sh running + setup-site.sh completed.
# Serves on 0.0.0.0:8000 (gunicorn-style dev server via `bench start`).
# ============================================================================
set -euo pipefail

export PATH="$HOME/.local/node24/bin:$HOME/.local/bin:$PATH"
export FRAPPE_PRELOAD_DATABASE_DRIVERS=none
cd "$HOME/frappe-bench"

SITE="${SITE:-$(cat sites/currentsite.txt 2>/dev/null || true)}"
echo "[bench] site: ${SITE:-<default>}"
echo "[bench] redis: $(redis-cli -h 127.0.0.1 ping 2>/dev/null || echo DOWN)"
echo "[bench] db: $(python3 -c "
import pymysql, os
try:
    pymysql.connect(host='127.0.0.1', port=int(os.environ.get('PORTABLE_DB_PORT', '3306')),
                    user='root', password=os.environ.get('PORTABLE_DB_ROOT_PASSWORD', 'root'),
                    connect_timeout=3).close()
    print('OK')
except Exception:
    print('DOWN')
")"

exec bench start
