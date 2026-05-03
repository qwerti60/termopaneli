#!/usr/bin/env bash
# Скопируйте в run_smsc_local.sh и подставьте пароль. Файл run_smsc_local.sh в .gitignore.
cd "$(dirname "$0")"
exec flutter run \
  --dart-define=SMSC_LOGIN=RosEcology \
  --dart-define=SMSC_PASSWORD='ВАШ_ПАРОЛЬ'
