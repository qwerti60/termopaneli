#!/usr/bin/env bash
# Установка vendor/ без глобальной команды «composer» (shared hosting).
# Запуск из SSH из каталога с composer.json:
#   cd /data/www/ivnovav.ru/tp_api && bash install_composer_deps.sh
#   (если скрипт лежит в tp_api рядом с composer.json)
# или из репозитория:
#   cd /path/to/backend && bash scripts/install_composer_deps.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "${SCRIPT_DIR}/composer.json" ]]; then
  ROOT="${SCRIPT_DIR}"
elif [[ -f "$(dirname "${SCRIPT_DIR}")/composer.json" ]]; then
  ROOT="$(dirname "${SCRIPT_DIR}")"
else
  echo "Не найден composer.json ни в ${SCRIPT_DIR}, ни в $(dirname "${SCRIPT_DIR}")"
  echo "Положите composer.json и composer.lock в текущий каталог и запустите скрипт оттуда или из backend/."
  exit 1
fi

cd "${ROOT}"
echo "Рабочий каталог: ${ROOT}"

if [[ ! -f composer.json ]]; then
  echo "Ошибка: нет composer.json в ${ROOT}"
  exit 1
fi

COMPOSER_PHAR="${ROOT}/composer.phar"
if [[ ! -f "$COMPOSER_PHAR" ]]; then
  echo "Скачиваю Composer (composer.phar) ..."
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php composer-setup.php --install-dir="${ROOT}" --filename=composer.phar
  php -r "unlink('composer-setup.php');"
fi

echo "Устанавливаю зависимости (Dompdf и др.)..."
php composer.phar install --no-dev --no-interaction

echo "Готово: ${ROOT}/vendor/"
