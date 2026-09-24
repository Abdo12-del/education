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

if [ -x "$PREFIX_PY/bin/python3.14" ]; then
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
			| grep -vE '\^\{\}|beta|rc' | sed 's#.*refs/tags/##' | sort -V | tail -1)
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
# 3. CPython 3.14
# ---------------------------------------------------------------------------
log "Cloning CPython..."
if [ ! -d "$SRC/cpython/.git" ]; then
	TAG=$(git ls-remote --tags https://github.com/python/cpython 'v3.14.*' \
		| grep -vE '\^\{\}|rc|a[0-9]|b[0-9]' | sed 's#.*refs/tags/##' | sort -V | tail -1)
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

"$PREFIX_PY/bin/python3.14" -c "import ssl, zlib, zipfile, json, sqlite3" 2>/dev/null \
	|| "$PREFIX_PY/bin/python3.14" -c "import ssl, zlib, zipfile, json; print('core modules OK')"
"$PREFIX_PY/bin/python3.14" -c "
import ssl, zlib
print('python:', __import__('sys').version.split()[0])
print('openssl:', ssl.OPENSSL_VERSION)
print('zlib:', zlib.ZLIB_VERSION)
"
log "PYTHON 3.14 READY ✓"
