#!/usr/bin/env bash
# ============================================================================
# Build Python 3.14 from source (frappe develop requires >=3.14,<3.15).
# No system dev headers exist in this sandbox, so zlib and OpenSSL are built
# first from GitHub sources, then CPython is configured against them.
# Output: ~/.local/python314
# ============================================================================
set -euo pipefail

log() { echo "[build-python $(date +%H:%M:%S)] $*"; }
PREFIX_ZLIB="$HOME/.local/zlib"
PREFIX_SSL="$HOME/.local/openssl"
PREFIX_PY="$HOME/.local/python314"
SRC="$HOME/src"

if [ -x "$PREFIX_PY/bin/python3.14" ] && [ -z "${PYTHON_REBUILD:-}" ]; then
	log "Python 3.14 already present"
	exit 0
fi

mkdir -p "$SRC"
export PATH="$PREFIX_ZLIB/bin:$PREFIX_SSL/bin:$PATH"

# ---------------------------------------------------------------------------
# 1. zlib (headers for CPython's zipimport/pip)
# ---------------------------------------------------------------------------
if [ ! -f "$PREFIX_ZLIB/include/zlib.h" ]; then
	log "Building zlib..."
	[ -d "$SRC/zlib/.git" ] || git clone --depth 1 --branch v1.3.1 https://github.com/madler/zlib "$SRC/zlib"
	(cd "$SRC/zlib" && ./configure --prefix="$PREFIX_ZLIB" && make -j2 && make install)
fi
log "zlib: $(ls "$PREFIX_ZLIB/include/zlib.h")"

# ---------------------------------------------------------------------------
# 2. OpenSSL (headers + libs for ssl/https in CPython & pip)
# ---------------------------------------------------------------------------
if [ ! -f "$PREFIX_SSL/include/openssl/ssl.h" ]; then
	log "Building OpenSSL (this takes a few minutes)..."
	if [ ! -d "$SRC/openssl/.git" ]; then
		# pick latest stable 3.x tag
		TAG=$(git ls-remote --tags https://github.com/openssl/openssl 'openssl-3.*' \
			| sed -n 's#.*refs/tags/\(openssl-3\.[0-9][0-9]*\.[0-9][0-9]*\)$#\1#p' | sort -V | tail -1)
		log "openssl tag: $TAG"
		git clone --depth 1 --branch "$TAG" https://github.com/openssl/openssl "$SRC/openssl"
	fi
	(cd "$SRC/openssl" \
		&& ./config --prefix="$PREFIX_SSL" --openssldir="$PREFIX_SSL/ssl" \
			threads shared --libdir=lib -Wl,-rpath="$PREFIX_SSL/lib" \
		&& make -j2 \
		&& make install_sw install_ssldirs)
fi
log "openssl: $(ls "$PREFIX_SSL/include/openssl/ssl.h")"

# ---------------------------------------------------------------------------
# 2b. libffi (headers + lib for CPython's _ctypes; npm ships the release
#     tarball with a pregenerated configure, no autotools needed here)
# ---------------------------------------------------------------------------
PREFIX_FFI="$HOME/.local/ffi"
if [ ! -f "$PREFIX_FFI/lib/pkgconfig/libffi.pc" ]; then
	log "Building libffi (for _ctypes)..."
	rm -rf "$SRC/libffi-npm" && mkdir -p "$SRC/libffi-npm"
	TGZ_URL=$(curl -s https://registry.npmjs.org/libffi | python3 -c "
import json, sys
v = json.load(sys.stdin)["dist-tags"]["latest"]
print(f'https://registry.npmjs.org/libffi/-/libffi-{v}.tgz')")
	curl -fsSL "$TGZ_URL" -o /tmp/libffi.tgz
	tar -xzf /tmp/libffi.tgz -C "$SRC/libffi-npm" 2>/dev/null || tar -xzf /tmp/libffi.tgz -C "$SRC/libffi-npm"
	rm -f /tmp/libffi.tgz
	FFI_DIR=$(echo "$SRC"/libffi-npm/*)
	(cd "$FFI_DIR" && ./configure --prefix="$PREFIX_FFI" && make -j2 && make install)
fi
export PKG_CONFIG_PATH="$PREFIX_FFI/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
log "libffi: $(pkg-config --modversion libffi 2>/dev/null || echo '?')"

# ---------------------------------------------------------------------------
# 2c. SQLite amalgamation (for CPython's _sqlite3 — frappe search + erpnext
#     item search import sqlite3). Source: npm better-sqlite3 vendors it.
# ---------------------------------------------------------------------------
PREFIX_SQLITE="$HOME/.local/sqlite3"
if [ ! -f "$PREFIX_SQLITE/lib/pkgconfig/sqlite3.pc" ]; then
	log "Building SQLite amalgamation (for _sqlite3)..."
	rm -rf "$SRC/sqlite-amalg" && mkdir -p "$SRC/sqlite-amalg"
	BSQ_VER=$(curl -s https://registry.npmjs.org/better-sqlite3 | python3 -c 'import json,sys; print(json.load(sys.stdin)["dist-tags"]["latest"])')
	curl -fsSL "https://registry.npmjs.org/better-sqlite3/-/better-sqlite3-$BSQ_VER.tgz" -o /tmp/bsq.tgz
	tar -xzf /tmp/bsq.tgz -C "$SRC/sqlite-amalg" 2>/dev/null || true
	rm -f /tmp/bsq.tgz
	SQLITE_SRC=$(dirname "$(find "$SRC/sqlite-amalg" -name sqlite3.c | head -1)")
	mkdir -p "$PREFIX_SQLITE/lib/pkgconfig" "$PREFIX_SQLITE/include"
	cp "$SQLITE_SRC/sqlite3.c" "$SQLITE_SRC/sqlite3.h" "$SQLITE_SRC/sqlite3ext.h" "$SRC/sqlite-amalg/"
	cd "$SRC/sqlite-amalg"
	gcc -O2 -fPIC -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_RTREE \
		-DSQLITE_ENABLE_MEMORY_MANAGEMENT -c sqlite3.c -o sqlite3.o
	ar rcs libsqlite3.a sqlite3.o
	cp sqlite3.h sqlite3ext.h "$PREFIX_SQLITE/include/"
	cp libsqlite3.a "$PREFIX_SQLITE/lib/"
	cat > "$PREFIX_SQLITE/lib/pkgconfig/sqlite3.pc" <<'PC'
prefix=$HOME/.local/sqlite3
libdir=${prefix}/lib
includedir=${prefix}/include

Name: SQLite
Description: SQL database engine
Version: 3.50.0
Libs: -L${libdir} -lsqlite3 -lm -lpthread
Cflags: -I${includedir}
PC
	cd "$SRC/cpython" 2>/dev/null || cd "$SRC"
fi
export PKG_CONFIG_PATH="$PREFIX_SQLITE/lib/pkgconfig:$PKG_CONFIG_PATH"
log "sqlite3: $(pkg-config --modversion sqlite3 2>/dev/null || echo '?')"

# ---------------------------------------------------------------------------
# 3. CPython 3.14
# ---------------------------------------------------------------------------
log "Cloning CPython..."
if [ ! -d "$SRC/cpython/.git" ]; then
	TAG=$(git ls-remote --tags https://github.com/python/cpython 'v3.14.*' \
		| sed -n 's#.*refs/tags/\(v3\.14\.[0-9][0-9]*\)$#\1#p' | sort -V | tail -1)
	log "cpython tag: $TAG"
	git clone --depth 1 --branch "$TAG" https://github.com/python/cpython "$SRC/cpython"
fi

log "Configuring CPython (with OpenSSL=$PREFIX_SSL, ZLIB=$PREFIX_ZLIB)..."
cd "$SRC/cpython"
LDFLAGS="-L$PREFIX_ZLIB/lib -Wl,-rpath,$PREFIX_ZLIB/lib" \
CPPFLAGS="-I$PREFIX_ZLIB/include" \
./configure --prefix="$PREFIX_PY" \
	--with-openssl="$PREFIX_SSL" \
	--with-openssl-rpath=auto \
	--with-zlib="$PREFIX_ZLIB" \
	--disable-shared \
	--with-ensurepip=yes \
	2>&1 | tail -5

log "Compiling CPython (make -j2, ~5-10 minutes)..."
make -j2 2>&1 | tail -5
make install 2>&1 | tail -5

"$PREFIX_PY/bin/python3.14" -c "import ssl, zlib, zipfile, json, ctypes; print('core modules OK (ctypes included)')"
"$PREFIX_PY/bin/python3.14" -c "
import ssl, zlib
print('python:', __import__('sys').version.split()[0])
print('openssl:', ssl.OPENSSL_VERSION)
print('zlib:', zlib.ZLIB_VERSION)
"
log "PYTHON 3.14 READY ✓"
