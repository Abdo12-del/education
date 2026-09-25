#!/usr/bin/env bash
# Helper for local bring-up: wipe any partial site + DBs, then run setup-site.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
rm -rf "$HOME/frappe-bench/sites/school.localhost" \
       "$HOME/frappe-bench/sites/8000-ij2yzae0ypot9ylpkej3n.e2b.app"
/home/user/education/local-db/.venv/bin/python - <<'PY'
import pymysql
c = pymysql.connect(host="127.0.0.1", user="root", password="root")
cur = c.cursor()
cur.execute("SHOW DATABASES")
for (d,) in cur.fetchall():
    if d not in ("information_schema", "mysql", "performance_schema", "sys"):
        cur.execute(f"DROP DATABASE `{d}`")
        print("dropped", d)
PY
exec bash scripts/local/setup-site.sh
