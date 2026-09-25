#!/usr/bin/env bash
SRC="${SRC:-$HOME/src}"   # clone root (overridable by caller)
# ============================================================================
# Applies the MySQL 5.7 compatibility patches to the local frappe/erpnext
# clones used by bench (Frappe officially targets MariaDB >= 10.6; we run the
# portable MySQL 5.7.29 from local-db/). Idempotent — safe to re-run.
#
# Patches:
#   frappe pyproject : drop mysqlclient (no MySQL C headers in this sandbox;
#                      frappe runs on PyMySQL via use_mysqlclient=0)
#   yarn locks       : registry.yarnpkg.com is blocked -> registry.npmjs.org
#   schema.py        : no DEFAULT clause on TEXT/BLOB/JSON columns (MySQL)
#   mariadb/schema.py: no "ADD UNIQUE INDEX IF NOT EXISTS" (MariaDB syntax)
#   mariadb/database : no "ADD INDEX IF NOT EXISTS" (guarded by has_index)
#   query.py         : plain FOR UPDATE (MySQL 5.7 lacks NOWAIT/SKIP LOCKED)
#   doctype JSONs    : autoname "autoincrement" -> "hash" (no CREATE SEQUENCE)
# ============================================================================
set -euo pipefail

log() { echo "[patch-mysql57 $(date +%H:%M:%S)] $*"; }

FRAPPE="${FRAPPE_SRC:-$HOME/src/frappe}"
ERPNext="${ERPNEXT_SRC:-$HOME/src/erpnext}"

if [ ! -d "$FRAPPE/.git" ]; then
	log "SKIP: $FRAPPE not cloned yet"
	exit 0
fi

python3 - "$FRAPPE" "$ERPNext" <<'PY'
import json, sys, glob, os

frappe, erpnext = sys.argv[1], sys.argv[2]

# --- 1. drop mysqlclient from frappe pyproject (PyMySQL is used instead) ---
p = os.path.join(frappe, "pyproject.toml")
s = open(p).read()
changed = False
for line in ('    "mysqlclient==2.2.8",\n', '    "mysqlclient",\n'):
    if line in s:
        s = s.replace(line, "")
        changed = True
if changed:
    open(p, "w").write(s)
    print("patched pyproject: mysqlclient dropped")

# --- 2. yarn lockfiles -> registry.npmjs.org (yarnpkg.com blocked) ---
for lock in glob.glob(os.path.join(frappe, "**", "yarn.lock"), recursive=True) + \
            glob.glob(os.path.join(erpnext, "**", "yarn.lock"), recursive=True):
    s = open(lock).read()
    if "registry.yarnpkg.com" in s:
        open(lock, "w").write(s.replace("https://registry.yarnpkg.com",
                                        "https://registry.npmjs.org"))
        print("patched lock:", lock)

# --- 3. schema: no DEFAULT on text-ish columns (MySQL forbids it) ---
p = os.path.join(frappe, "frappe/database/schema.py")
s = open(p).read()
old = '\t\tif default is not None:\n\t\t\tcolumn_def += f" DEFAULT {default}"'
new = '''\t\tif default is not None:
\t\t\t# MySQL (unlike MariaDB) does not allow DEFAULT on TEXT/BLOB/JSON/GEOMETRY.
\t\t\t_base = column_def.split("(")[0].split(" ")[0].lower()
\t\t\t_no_default_types = (
\t\t\t\t"text", "tinytext", "mediumtext", "longtext",
\t\t\t\t"blob", "tinyblob", "mediumblob", "longblob",
\t\t\t\t"json", "geometry", "point", "linestring", "polygon",
\t\t\t\t"multipoint", "multilinestring", "multipolygon", "geometrycollection",
\t\t\t)
\t\t\tif _base not in _no_default_types:
\t\t\t\tcolumn_def += f" DEFAULT {default}"'''
if old in s:
    open(p, "w").write(s.replace(old, new, 1))
    print("patched schema.py: text DEFAULT stripped")

# --- 4. mariadb/schema.py: guarded unique index add (no IF NOT EXISTS) ---
p = os.path.join(frappe, "frappe/database/mariadb/schema.py")
s = open(p).read()
old = '''\t\tmodify_column_query.extend(
\t\t\t[f"ADD UNIQUE INDEX IF NOT EXISTS {col.fieldname} (`{col.fieldname}`)" for col in self.add_unique]
\t\t)'''
new = '''\t\t# MySQL has no "ADD UNIQUE INDEX IF NOT EXISTS" — check first (MariaDB syntax).
\t\tfor col in self.add_unique:
\t\t\tidx_name = f"idx_{self.table_name}_{col.fieldname}"
\t\t\tif not frappe.db.get_column_index(self.table_name, col.fieldname, unique=True):
\t\t\t\tmodify_column_query.append(f"ADD UNIQUE INDEX `{idx_name}` (`{col.fieldname}`)")'''
if old in s:
    open(p, "w").write(s.replace(old, new, 1))
    print("patched mariadb/schema.py: unique index guarded")

# --- 5. mariadb/database(+mysqlclient).py: plain ADD INDEX (guarded already) ---
for rel in ("frappe/database/mariadb/database.py", "frappe/database/mariadb/mysqlclient.py"):
    p = os.path.join(frappe, rel)
    if not os.path.exists(p):
        continue
    s = open(p).read()
    if "ADD INDEX IF NOT EXISTS `{}`({})" in s:
        open(p, "w").write(s.replace("ADD INDEX IF NOT EXISTS `{}`({})", "ADD INDEX `{}`({})"))
        print("patched", rel, ": plain ADD INDEX")

# --- 6. query.py: FOR UPDATE without NOWAIT/SKIP LOCKED (MySQL 5.7) ---
p = os.path.join(frappe, "frappe/database/query.py")
s = open(p).read()
old = "\t\tif for_update:\n\t\t\tself.query = self.query.for_update(skip_locked=skip_locked, nowait=not wait)"
new = "\t\tif for_update:\n\t\t\t# MySQL 5.7 has no NOWAIT / SKIP LOCKED (MariaDB/MySQL8 features).\n\t\t\tself.query = self.query.for_update(skip_locked=False, nowait=False)"
if old in s:
    open(p, "w").write(s.replace(old, new, 1))
    print("patched query.py: plain FOR UPDATE")

# --- 7. autoname autoincrement -> hash (MySQL 5.7 has no CREATE SEQUENCE) ---
for root in (frappe, erpnext):
    n = 0
    for f in glob.glob(os.path.join(root, "**", "doctype", "**", "*.json"), recursive=True):
        try:
            d = json.load(open(f))
        except Exception:
            continue
        if isinstance(d, dict) and d.get("autoname") == "autoincrement":
            d["autoname"] = "hash"
            json.dump(d, open(f, "w"), indent=1, ensure_ascii=False)
            n += 1
    if n:
        print(f"converted autoname in {os.path.basename(root)}: {n} doctypes")

print("mysql57 patches applied")
PY

log "DONE ✓"
