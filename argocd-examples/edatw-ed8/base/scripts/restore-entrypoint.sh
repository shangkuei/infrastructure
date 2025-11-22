#!/usr/bin/env bash
set -euo pipefail

if [[ -n ${FORCE_RECOVER:-} ]]; then
  rm -rf /var/lib/mysql/*
elif [[ $(find /var/lib/mysql -type f | wc -l) != "0" ]]; then
  ls -al /var/lib/mysql
  echo "Exit as /var/lib/mysql is not empty"
  exit 0
fi

echo "Running /entrypoint.sh"
bash /entrypoint.sh mysqld
