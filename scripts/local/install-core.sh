#!/usr/bin/env bash
# ============================================================================
# Madrasati — Portable local environment installer (restricted-network aware)
#
# The sandbox only allows github.com / pypi.org / registry.npmjs.org, so every
# component is fetched from an allowed channel:
#   - Node.js 24 + npm + yarn  .... npm registry tarballs
#   - MySQL server 5.7.29      ... npm package "mysql-server-5.7-lin-x64"
#   - libaio for mysqld        ... compiled here (scripts/local/libaio.c)
#   - Redis                    ... built from github.com/redis/redis source
#   - frappe/erpnext/payments  ... github clones (develop)
# Everything lands either in ~/.local (tools) or local-db/ (portable database).
# Usage: bash scripts/local/install-core.sh
# ============================================================================
set -euo pipefail

log() { echo "[install-core $(date +%H:%M:%S)] $*"; }
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCAL="$HOME/.local"

# ---------------------------------------------------------------------------
# 0. Python 3.14 (frappe develop requires >=3.14) built from source
# ---------------------------------------------------------------------------
if [ ! -x "$HOME/.local/python314/bin/python3.14" ]; then
	log "Python 3.14 missing -> building toolchain (zlib + OpenSSL + CPython)..."
	bash "$REPO/scripts/local/build-python.sh"
fi
PY314="$HOME/.local/python314/bin/python3.14"
log "python: $($PY314 --version 2>&1)"
# We run frappe on PyMySQL (use_mysqlclient=0); skip the mysqlclient preload.
export FRAPPE_PRELOAD_DATABASE_DRIVERS=none

# ---------------------------------------------------------------------------
# 1. Node.js 24 (frappe requires node >= 24) from the npm registry
# ---------------------------------------------------------------------------
mkdir -p "$LOCAL/node24"
if ! "$LOCAL/node24/bin/node" -e 'process.exit(process.versions.node.split(".")[0] >= 24 ? 0 : 1)' 2>/dev/null; then
	log "Downloading Node.js 24 (npm package node-linux-x64)..."
	# NOTE: the package's "latest" dist-tag may lag behind — pick the highest 24.x.
	NODE_TGZ=$(curl -s "https://registry.npmjs.org/node-linux-x64" | python3 -c "
import json, sys
versions = [v for v in json.load(sys.stdin)['versions'] if v.startswith('24.')]
versions.sort(key=lambda s: [int(x) for x in s.split('.')])
print(versions[-1])")
	log "node-linux-x64@$NODE_TGZ"
	curl -fsSL "https://registry.npmjs.org/node-linux-x64/-/node-linux-x64-$NODE_TGZ.tgz" -o /tmp/node24.tgz
	rm -rf "$LOCAL/node24" && mkdir -p "$LOCAL/node24"
	tar -xzf /tmp/node24.tgz -C "$LOCAL/node24" --strip-components=1
	rm -f /tmp/node24.tgz
fi
export PATH="$LOCAL/node24/bin:$LOCAL/bin:$PATH"
log "node=$(node -v)"

# npm (not bundled in node-linux-x64) + yarn classic, both from the registry
if [ ! -x "$LOCAL/node24/bin/npm" ]; then
	log "Installing npm CLI..."
	NPM_VER=$(curl -s "https://registry.npmjs.org/npm/latest" | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])")
	curl -fsSL "https://registry.npmjs.org/npm/-/npm-$NPM_VER.tgz" -o /tmp/npm.tgz
	mkdir -p "$LOCAL/node24/lib/node_modules"
	tar -xzf /tmp/npm.tgz -C "$LOCAL/node24/lib/node_modules"
	rm -rf "$LOCAL/node24/lib/node_modules/npm" && mv "$LOCAL/node24/lib/node_modules/package" "$LOCAL/node24/lib/node_modules/npm"
	ln -sf ../lib/node_modules/npm/bin/npm-cli.js "$LOCAL/node24/bin/npm"
	ln -sf ../lib/node_modules/npm/bin/npx-cli.js "$LOCAL/node24/bin/npx"
	rm -f /tmp/npm.tgz
fi
if [ ! -x "$LOCAL/node24/bin/yarn" ]; then
	log "Installing yarn 1.22..."
	YARN_VER=1.22.22
	curl -fsSL "https://registry.npmjs.org/yarn/-/yarn-$YARN_VER.tgz" -o /tmp/yarn.tgz
	mkdir -p "$LOCAL/yarn"
	tar -xzf /tmp/yarn.tgz -C "$LOCAL/yarn" --strip-components=1
	ln -sf "$LOCAL/yarn/bin/yarn.js" "$LOCAL/node24/bin/yarn"
	ln -sf "$LOCAL/yarn/bin/yarn.js" "$LOCAL/node24/bin/yarnpkg"
	rm -f /tmp/yarn.tgz
fi
log "npm=$(npm -v) yarn=$(yarn -v)"

# ---------------------------------------------------------------------------
# 2. bench CLI (isolated venv, exposed on ~/.local/bin)
# ---------------------------------------------------------------------------
BENCHVENV="$LOCAL/bench-venv"
if [ ! -x "$BENCHVENV/bin/bench" ]; then
	log "Installing frappe-bench CLI..."
	python3 -m venv "$BENCHVENV"
	"$BENCHVENV/bin/pip" install -q --upgrade pip
	"$BENCHVENV/bin/pip" install -q frappe-bench
fi
mkdir -p "$LOCAL/bin"
ln -sf "$BENCHVENV/bin/bench" "$LOCAL/bin/bench"
# bench 5.x shells out to `uv` for the bench environment (PyPI wheel provides it)
if [ ! -x "$BENCHVENV/bin/uv" ]; then
	log "Installing uv (required by modern bench)..."
	"$BENCHVENV/bin/pip" install -q uv
fi
ln -sf "$BENCHVENV/bin/uv" "$LOCAL/bin/uv"
log "bench=$(bench --version 2>/dev/null || echo '?') uv=$(uv --version 2>/dev/null || echo '?')"

# pkg-config: required by bench when installing frappe (presence check).
# Built from source with pkgconf's autotools-free "lite" Makefile.
if ! command -v pkg-config >/dev/null 2>&1; then
	log "Building pkgconf (pkg-config) from source..."
	if [ ! -d "$HOME/src/pkgconf/.git" ]; then
		git clone --depth 1 --branch release/3.0 https://github.com/pkgconf/pkgconf.git "$HOME/src/pkgconf"
	fi
	(cd "$HOME/src/pkgconf" && make -f Makefile.lite \
		SYSTEM_LIBDIR=/usr/lib \
		SYSTEM_INCLUDEDIR=/usr/include \
		PKG_DEFAULT_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig)
	sudo ln -sf "$HOME/src/pkgconf/pkgconf-lite" /usr/local/bin/pkgconf
	sudo ln -sf "$HOME/src/pkgconf/pkgconf-lite" /usr/local/bin/pkg-config
fi
log "pkg-config=$(pkg-config --version 2>/dev/null || echo '?')"

# ---------------------------------------------------------------------------
# 3. Portable MySQL server (npm mysql-server-5.7-lin-x64) + libaio shim
# ---------------------------------------------------------------------------
MYSQL_TGZ_URL="https://registry.npmjs.org/mysql-server-5.7-lin-x64/-/mysql-server-5.7-lin-x64-1.0.0.tgz"
mkdir -p "$REPO/local-db"
if [ ! -x "$REPO/local-db/mysql57/mysqld" ]; then
	log "Downloading portable MySQL 5.7 server..."
	curl -fsSL "$MYSQL_TGZ_URL" -o /tmp/mysql57.tgz
	rm -rf /tmp/mysql57-pkg && mkdir -p /tmp/mysql57-pkg
	tar -xzf /tmp/mysql57.tgz -C /tmp/mysql57-pkg
	rm -rf "$REPO/local-db/mysql57"
	mv /tmp/mysql57-pkg/package/server "$REPO/local-db/mysql57"
	rm -rf /tmp/mysql57-pkg /tmp/mysql57.tgz
	chmod +x "$REPO/local-db/mysql57/mysqld"
fi
if [ ! -f "$REPO/local-db/lib/libaio.so.1" ]; then
	log "Building libaio shim for mysqld..."
	mkdir -p "$REPO/local-db/lib"
	gcc -shared -fPIC -O2 -o "$REPO/local-db/lib/libaio.so.1" \
		"$REPO/scripts/local/libaio.c" \
		-Wl,--version-script="$REPO/scripts/local/libaio.map" \
		-Wl,-soname,libaio.so.1
fi
LD_LIBRARY_PATH="$REPO/local-db/lib" "$REPO/local-db/mysql57/mysqld" --version

# python admin helper (pymysql) for database bootstrap scripts
if [ ! -x "$REPO/local-db/.venv/bin/python" ]; then
	log "Creating db-admin venv (pymysql)..."
	python3 -m venv "$REPO/local-db/.venv"
	"$REPO/local-db/.venv/bin/pip" install -q pymysql
fi

# ---------------------------------------------------------------------------
# 3b. Helper shims (lost with ~/.local on environment resets — recreate here)
# ---------------------------------------------------------------------------
# crontab: bench init writes a backup schedule; python-crontab needs the binary.
if [ ! -x "$LOCAL/bin/crontab" ]; then
	cat > "$LOCAL/bin/crontab" <<'CRON'
#!/bin/sh
# Minimal crontab shim for bench (no cron daemon in this sandbox).
case "${1:-}" in
	-l) cat "$HOME/.crontab.shim" 2>/dev/null || true; exit 0 ;;
	-r) : > "$HOME/.crontab.shim" 2>/dev/null || true; exit 0 ;;
	*)  cat >> "$HOME/.crontab.shim" 2>/dev/null || true; exit 0 ;;
esac
CRON
	chmod +x "$LOCAL/bin/crontab"
fi
# python-crontab hardcodes /usr/bin/crontab
if [ ! -x /usr/bin/crontab ]; then
	sudo cp "$LOCAL/bin/crontab" /usr/bin/crontab 2>/dev/null || true
fi

# mariadb/mysql CLI shim: frappe restores the framework SQL through this client;
# the portable npm dist ships only mysqld, so we emulate the CLI via PyMySQL.
if [ ! -x "$LOCAL/bin/mariadb" ]; then
	cat > "$LOCAL/bin/mariadb" <<'MARIADB'
#!/usr/bin/env python3
"""Minimal mariadb/mysql CLI shim for the portable DB (frappe restore path)."""
import os, sys

def main():
    user, password, host, port, sock, db = "root", "", "127.0.0.1", 3306, None, None
    for arg in sys.argv[1:]:
        if arg.startswith("--user="): user = arg.split("=", 1)[1]
        elif arg.startswith("--password="): password = arg.split("=", 1)[1]
        elif arg.startswith("--host="): host = arg.split("=", 1)[1]
        elif arg.startswith("--port="): port = int(arg.split("=", 1)[1])
        elif arg.startswith("--socket="): sock = arg.split("=", 1)[1]
        elif arg.startswith("-"): continue
        else: db = arg
    sql = sys.stdin.buffer.read()
    if not sql:
        return 0
    import pymysql
    from pymysql.constants import CLIENT
    conn = pymysql.connect(user=user, password=password,
                           host=None if sock else host, port=port, unix_socket=sock,
                           database=db, client_flag=CLIENT.MULTI_STATEMENTS,
                           local_infile=True)
    try:
        with conn.cursor() as cur:
            cur.execute(sql.decode("utf-8", errors="replace"))
            while cur.nextset():
                pass
        conn.commit()
    finally:
        conn.close()
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        sys.stderr.write(f"mariadb-shim: {exc}\n")
        sys.exit(1)
MARIADB
	chmod +x "$LOCAL/bin/mariadb"
	# point the shim at the db-admin venv (has pymysql) instead of system python
	sed -i "1s|.*|#!$REPO/local-db/.venv/bin/python|" "$LOCAL/bin/mariadb"
	ln -sf "$LOCAL/bin/mariadb" "$LOCAL/bin/mysql"
fi

# ---------------------------------------------------------------------------
# 4. Redis built from source (no apt in this environment)
# ---------------------------------------------------------------------------
if [ ! -x "$LOCAL/bin/redis-server" ]; then
	log "Building Redis from source..."
	if [ ! -d "$HOME/src/redis/.git" ]; then
		git clone --depth 1 --branch 7.2.5 https://github.com/redis/redis "$HOME/src/redis" \
			|| git clone --depth 1 https://github.com/redis/redis "$HOME/src/redis"
	fi
	(cd "$HOME/src/redis" && make -j"$(nproc)" MALLOC=libc BUILD_TLS=no redis-server redis-cli)
	ln -sf "$HOME/src/redis/src/redis-server" "$LOCAL/bin/redis-server"
	ln -sf "$HOME/src/redis/src/redis-cli" "$LOCAL/bin/redis-cli"
fi
"$LOCAL/bin/redis-server" --version | head -1

# ---------------------------------------------------------------------------
# 5. Shallow source clones (develop branches match this app's pyproject:
#    frappe >=17.0.0-dev,<18.0.0)
# ---------------------------------------------------------------------------
SRC="$HOME/src"
mkdir -p "$SRC"
clone() { # clone <url> <dest> <branch>
	if [ ! -d "$2/.git" ]; then
		log "Cloning $1 ($3)..."
		git clone --depth 1 --branch "$3" "$1" "$2"
	fi
}
clone https://github.com/frappe/frappe "$SRC/frappe" develop
clone https://github.com/frappe/erpnext "$SRC/erpnext" develop
clone https://github.com/frappe/payments "$SRC/payments" develop

# MySQL 5.7 compatibility patches (must land before bench init clones frappe)
bash "$REPO/scripts/local/patch-frappe-mysql57.sh"

# yarn should resolve new packages from registry.npmjs.org (yarnpkg.com blocked)
if command -v yarn >/dev/null 2>&1; then
	yarn config set registry https://registry.npmjs.org/ >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 6. bench init
# ---------------------------------------------------------------------------
BENCH="$HOME/frappe-bench"
if [ ! -d "$BENCH/apps/frappe" ]; then
	log "bench init (creating $BENCH, this takes a while)..."
	(cd "$HOME" && bench init --skip-assets --skip-redis-config-generation \
		--frappe-path "$SRC/frappe" --python "${PY314:-$(command -v python3)}" frappe-bench)
fi
cd "$BENCH"

# Upstream develop added mysqlclient (sdist-only; needs libmysqlclient headers we
# cannot fetch). We run frappe on PyMySQL -- strip the pin and repair the install
# if bench init died inside its app-install step.
for pt in "$BENCH/apps"/*/pyproject.toml; do
	if [ -f "$pt" ] && grep -q '"mysqlclient==' "$pt"; then
		sed -i '/"mysqlclient==/d' "$pt"
		log "stripped mysqlclient pin from $pt"
	fi
done
if ! "$BENCH/env/bin/python" -c "import frappe" >/dev/null 2>&1; then
	log "repairing frappe install into bench env (uv pip -e apps/frappe)..."
	"$BENCHVENV/bin/uv" pip install --quiet -e "$BENCH/apps/frappe" \
		--python "$BENCH/env/bin/python"
fi

# frappe's JS deps (esbuild/fast-glob/...): partial bench-init runs die before
# yarn install, and fresh apps clones still carry blocked yarnpkg.com URLs.
for lock in "$BENCH/apps"/*/yarn.lock; do
	[ -f "$lock" ] && sed -i 's#registry\.yarnpkg\.com#registry.npmjs.org#g' "$lock"
done
for appdir in "$BENCH/apps"/*/; do
	if [ -f "$appdir/package.json" ] && [ ! -d "$appdir/node_modules" ]; then
		log "yarn install in $appdir"
		(cd "$appdir" && yarn install --silent)
	fi
done

# Use our locally built redis (6379); drop per-bench redis/socketio/watch entries.
sed -i \
	-e 's/^watch:/# watch:/' \
	-e 's/^schedule:/# schedule:/' \
	-e 's/^socketio:/# socketio:/' \
	-e 's/^redis_socketio:/# redis_socketio:/' \
	-e 's/^redis_cache:/# redis_cache:/' \
	-e 's/^redis_queue:/# redis_queue:/' \
	Procfile || true
log "Procfile:" && cat Procfile

# ---------------------------------------------------------------------------
# 7. Apps: payments + erpnext (education is added later by setup-site.sh)
# ---------------------------------------------------------------------------
if [ ! -d apps/payments ]; then
	log "Installing payments app..."
	bench get-app "$SRC/payments"
fi
if [ ! -d apps/erpnext ]; then
	log "Installing erpnext app..."
	bench get-app "$SRC/erpnext"
fi

log "CORE DONE ✓ — next: scripts/local/start-db.sh then scripts/local/setup-site.sh"
