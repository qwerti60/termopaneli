#!/usr/bin/env bash
# Smoke tests for docs/testing_catalog.md §4 (and optional §6).
# Usage:
#   API='https://host/tp_api' bash scripts/smoke_catalog_api.sh
# Optional — first catalog image over HTTP (§6):
#   API='https://host/tp_api' STATIC_ORIGIN='https://host' bash scripts/smoke_catalog_api.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${API:-}" ]]; then
  echo "Set API to the base URL without trailing slash, e.g. API='https://example.com/tp_api'" >&2
  exit 1
fi

API="${API%/}"
BODY=/tmp/smoke_catalog_body.json

http_get_to() {
  local url="$1"
  local out="$2"
  curl -sS -o "$out" -w '%{http_code}' "$url"
}

require_200() {
  local name="$1"
  local url="$2"
  local out="${3:-$BODY}"
  local code
  code="$(http_get_to "$url" "$out")" || return 1
  if [[ "$code" != "200" ]]; then
    echo "FAIL $name: HTTP $code (expected 200) URL=$url" >&2
    exit 1
  fi
  echo "OK  $name (HTTP 200)"
}

require_200 "slope list" "$API/api/v1/catalog/list.php?category=slope&limit=200" "$BODY"
python3 - <<'PY'
import json, pathlib, re
p = pathlib.Path("/tmp/smoke_catalog_body.json")
j = json.loads(p.read_text(encoding="utf-8"))
items = j.get("items") or []
if not items:
    raise SystemExit("FAIL slope: items empty")
hits = 0
for it in items:
    n = (it.get("name") or "") + " " + (it.get("title") or "")
    if re.search(r"\d+\s*мм", n) or "коричневый" in n.lower():
        hits += 1
if hits < 2:
    raise SystemExit("FAIL slope: expected several names with «… мм» or «коричневый…», got hits=%s" % hits)
for it in items:
    if it.get("sku") == "SLP-MT-RAL-CUSTOM":
        raise SystemExit("FAIL slope: inactive SKU SLP-MT-RAL-CUSTOM must not appear")
    if it.get("category") != "slope":
        raise SystemExit("FAIL slope: wrong category %r" % (it.get("category"),))
cm = [it for it in items if it.get("source") == "catalog_materials"]
if not cm:
    raise SystemExit("FAIL slope: no catalog_materials items")
for it in cm[:5]:
    raw = it.get("raw")
    if not isinstance(raw, dict) or "package_qty" not in raw:
        raise SystemExit("FAIL slope: raw missing package_qty for sku=%r" % (it.get("sku"),))
print("OK  slope JSON (items, seed-like names, no RAL custom, package_qty in raw)")
PY

for cat in soffit_lining front_overhang consumable; do
  require_200 "list category=$cat" "$API/api/v1/catalog/list.php?category=${cat}&limit=200" "$BODY"
  python3 - "$cat" <<'PY'
import json, pathlib, sys
cat = sys.argv[1]
p = pathlib.Path("/tmp/smoke_catalog_body.json")
j = json.loads(p.read_text(encoding="utf-8"))
n = len(j.get("items") or [])
need = 2
if n < need:
    raise SystemExit("FAIL %s: expected at least %s items, got %s" % (cat, need, n))
print("OK  category=%s (%s items)" % (cat, n))
PY
done

require_200 "panel list" "$API/api/v1/catalog/list.php?category=panel&limit=50" "$BODY"
python3 - <<'PY'
import json, pathlib
j = json.loads(pathlib.Path("/tmp/smoke_catalog_body.json").read_text(encoding="utf-8"))
if not j.get("items"):
    raise SystemExit("FAIL panel: items empty")
print("OK  panel JSON (non-empty items)")
PY

FILTER_BODY=/tmp/smoke_catalog_filter.json
BASE="$API/api/v1/catalog/list.php"
code="$(curl -sS -o "$FILTER_BODY" -w '%{http_code}' -G "$BASE" \
  --data-urlencode "category=slope" \
  --data-urlencode "color=Белый" \
  --data-urlencode "limit=200")"
if [[ "$code" != "200" ]]; then
  echo "FAIL filter color Белый: HTTP $code" >&2
  exit 1
fi
python3 - <<'PY'
import json, pathlib
j = json.loads(pathlib.Path("/tmp/smoke_catalog_filter.json").read_text(encoding="utf-8"))
for it in j.get("items") or []:
    if it.get("source") != "catalog_materials":
        continue
    if (it.get("color") or "") != "Белый":
        raise SystemExit("FAIL filter color: item sku=%r has color=%r" % (it.get("sku"), it.get("color")))
print("OK  filter color=Белый (catalog_materials only white)")
PY

code="$(curl -sS -o "$FILTER_BODY" -w '%{http_code}' -G "$BASE" \
  --data-urlencode "category=slope" \
  --data-urlencode "material=Пластик" \
  --data-urlencode "thickness=250" \
  --data-urlencode "limit=200")"
if [[ "$code" != "200" ]]; then
  echo "FAIL filter material+thickness: HTTP $code" >&2
  exit 1
fi
python3 - <<'PY'
import json, pathlib
j = json.loads(pathlib.Path("/tmp/smoke_catalog_filter.json").read_text(encoding="utf-8"))
items = [it for it in (j.get("items") or []) if it.get("source") == "catalog_materials"]
if not items:
    raise SystemExit("FAIL filter material+thickness: no materials in response")
for it in items:
    if (it.get("material") or "") != "Пластик":
        raise SystemExit("FAIL filter: sku=%r material=%r" % (it.get("sku"), it.get("material")))
    th = it.get("thickness_mm")
    w = it.get("width_mm")
    ok = (th == 250) or (th is None and w == 250)
    if not ok:
        raise SystemExit("FAIL filter thickness=250: sku=%r thickness_mm=%s width_mm=%s" % (it.get("sku"), th, w))
print("OK  filter material=Пластик thickness=250")
PY

if [[ -n "${STATIC_ORIGIN:-}" ]]; then
  ORIGIN="${STATIC_ORIGIN%/}"
  python3 - "$ORIGIN" <<'PY'
import json, pathlib, subprocess, sys
origin = sys.argv[1]
slope = json.loads(pathlib.Path("/tmp/smoke_catalog_body.json").read_text(encoding="utf-8"))
path = None
for it in slope.get("items") or []:
    if it.get("source") != "catalog_materials":
        continue
    ip = (it.get("image_path") or "").strip()
    if ip:
        path = ip
        break
if not path:
    raise SystemExit("FAIL §6: no image_path on catalog_materials item")
url = origin.rstrip("/") + "/" + path.lstrip("/")
p = subprocess.run(
    ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}", "-I", url],
    capture_output=True,
    text=True,
)
code = (p.stdout or "").strip()
if code != "200":
    raise SystemExit("FAIL §6 image HEAD %s -> HTTP %s" % (url, code))
print("OK  §6 image HEAD %s -> 200" % url)
PY
else
  echo "SKIP §6 image (set STATIC_ORIGIN=https://… where /catalog/ is served)"
fi

echo "All smoke checks passed."
