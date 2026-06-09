#!/usr/bin/env bash
# Копирование выбранных модулей админки в каталог нового проекта.
# Использование:
#   ./admin-kit/copy_to_project.sh /path/to/tp_api [core|full]
#
# core — ядро + admin API auth
# full — admin-web + include + api/v1/admin (весь набор termopaneli)

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-}"
MODE="${2:-core}"

if [[ -z "$DEST" ]]; then
  echo "Usage: $0 /path/to/tp_api [core|full]" >&2
  exit 1
fi

SRC="$ROOT/backend/public"
mkdir -p "$DEST"/{admin-web,include,api/v1/admin/auth}

copy() {
  local rel="$1"
  local src="$SRC/$rel"
  local dst="$DEST/$rel"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$(dirname "$dst")/"
    echo "  + $rel"
  else
    echo "  skip (missing): $rel" >&2
  fi
}

echo "Copy admin-kit ($MODE) -> $DEST"

if [[ "$MODE" == "full" ]]; then
  rsync -a --delete "$SRC/admin-web/" "$DEST/admin-web/"
  rsync -a "$SRC/include/" "$DEST/include/"
  rsync -a "$SRC/api/v1/admin/" "$DEST/api/v1/admin/"
  mkdir -p "$DEST/catalog_uploads"
  touch "$DEST/catalog_uploads/.gitkeep"
  echo "Done (full)."
  exit 0
fi

# core
for f in \
  admin-web/bootstrap_web.php \
  admin-web/index.php \
  admin-web/login.php \
  admin-web/logout.php \
  admin-web/login_reset.php \
  admin-web/admin_password.php \
  admin-web/admin_journal.php \
  include/api_bootstrap.php \
  include/admin_auth.php \
  include/admin_login_verify.php \
  include/admin_audit_log.php \
  include/admin_mail.php \
  include/admin_password_service.php \
  api/v1/admin/auth/login.php \
  api/v1/admin/auth/logout.php
do
  copy "$f"
done

if [[ ! -f "$DEST/config.php" ]] && [[ -f "$ROOT/admin-kit/config.admin.example.php" ]]; then
  cp "$ROOT/admin-kit/config.admin.example.php" "$DEST/config.example.admin.php"
  echo "  + config.example.admin.php (rename to config.php)"
fi

echo "Done (core). Add modules from admin-kit/MODULES.md as needed."
