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

mysqladmin --defaults-extra-file=<(_extra_my_cnf) shutdown
rm -f /var/lib/mysql/mysql.sock

echo "Cleanup exist hard copy..."
rm -rf /database/*

ls -al /var/lib/mysql

echo "Perform hard copy..."
cp -r /var/lib/mysql/* /database
