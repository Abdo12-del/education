#!/usr/bin/env bash
# ============================================================================
# Registers the education app in the bench and creates the demo site:
#   - site named after the Arena preview host (Frappe matches Host header
#     exactly), plus alias links for localhost / school.localhost
#   - installs payments + erpnext + education apps
#   - builds all assets (desk bundles + portal)
# Requires: install-core.sh done, start-db.sh running, redis on 6379.
# Usage: bash scripts/local/setup-site.sh
# ============================================================================
set -euo pipefail

log() { echo "[setup-site $(date +%H:%M:%S)] $*"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BENCH="$HOME/frappe-bench"
# Run frappe on PyMySQL: no mysqlclient C library in this portable env.
export FRAPPE_PRELOAD_DATABASE_DRIVERS=none
export PATH="$HOME/.local/node24/bin:$HOME/.local/bin:$PATH"
cd "$BENCH"

PREVIEW_HOST="${PREVIEW_HOST:-8000-${E2B_SANDBOX_ID:-ij2yzae0ypot9ylpkej3n}.e2b.app}"
SITE="${SITE:-school.localhost}"
DB_PW="${PORTABLE_DB_ROOT_PASSWORD:-root}"

# ---------------------------------------------------------------------------
# 1. Register the education app (clone of this repository)
# ---------------------------------------------------------------------------
if [ ! -d apps/education ]; then
	log "Adding education app from $ROOT ..."
	bench get-app education "$ROOT"
fi
grep -qx education sites/apps.txt 2>/dev/null || echo education >>sites/apps.txt

# ---------------------------------------------------------------------------
# 2. Point the bench at the portable database + system redis
# ---------------------------------------------------------------------------
bench set-mariadb-host 127.0.0.1
bench set-redis-cache-host redis://127.0.0.1:6379
bench set-redis-queue-host redis://127.0.0.1:6379
bench set-redis-socketio-host redis://127.0.0.1:6379

# ---------------------------------------------------------------------------
# 3. Create the site (frappe comes in automatically)
# ---------------------------------------------------------------------------
# Must be set before new-site: DB setup already reads frappe.conf.
python3 - "$BENCH/sites/common_site_config.json" <<'PY'
import json, sys, os
path = sys.argv[1]
conf = json.load(open(path)) if os.path.exists(path) else {}
conf["use_mysqlclient"] = 0
conf["db_host"] = "127.0.0.1"
json.dump(conf, open(path, "w"), indent=4)
print("[setup-site] common_site_config:", {"use_mysqlclient": 0, "db_host": "127.0.0.1"})
PY

if [ ! -d "sites/$SITE" ]; then
	log "Creating site $SITE ..."
	bench new-site "$SITE" \
		--mariadb-root-password "$DB_PW" \
		--no-mariadb-socket \
		--admin-password admin
fi

# Frappe resolves the site from the request Host header exactly, so register
# aliases: the Arena preview hostname and plain localhost.
cd sites
for alias in "$PREVIEW_HOST" "localhost"; do
	if [ "$alias" != "$SITE" ] && [ ! -e "$alias" ]; then ln -s "$SITE" "$alias"; fi
done
cd ..

# ---------------------------------------------------------------------------
# 4. Install the apps on the site
# ---------------------------------------------------------------------------
for app in payments erpnext education; do
	log "Installing $app ..."
	# --force tolerates leftovers from a previously interrupted install
	bench --site "$SITE" install-app "$app" --force
done

bench --site "$SITE" set-config use_mysqlclient 0
bench --site "$SITE" set-config developer_mode 1
bench --site "$SITE" clear-cache
bench use "$SITE"

# ---------------------------------------------------------------------------
# 5. Build assets (frappe desk bundles, erpnext, education bundle, portal)
# ---------------------------------------------------------------------------
log "Building assets..."
bench build

log "SITE READY ✓ — start it with: bash scripts/local/start-bench.sh"
