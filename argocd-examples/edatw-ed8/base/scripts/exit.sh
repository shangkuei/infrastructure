#!/usr/bin/env bash
set -euo pipefail

_extra_my_cnf() {
  cat <<EOF
[client]
user=root
password="${MYSQL_ROOT_PASSWORD}"
socket=/var/run/mysqld/mysqld.sock
EOF
}

mysqladmin --defaults-extra-file=<(_extra_my_cnf) shutdown || true

exit 0
