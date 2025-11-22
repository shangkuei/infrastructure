#!/usr/bin/env bash
set -euo pipefail

_mysql_passfile() {
  cat <<EOF
[client]
user=root
password="${MYSQL_ROOT_PASSWORD}"
socket=/var/run/mysqld/mysqld.sock
EOF
}

mysql --defaults-extra-file=<(_mysql_passfile) -Bse "CREATE USER '${ED8_USER}'@'%' IDENTIFIED BY '${ED8_PASSWORD}'"
mysql --defaults-extra-file=<(_mysql_passfile) -Bse "GRANT ALL ON *.* TO '${ED8_USER}'@'%'"

pushd /restore
BACKUP_VERSION=${ED8_BACKUP_VERSION:-latest}
tar -xzf "/backups/${BACKUP_VERSION}.tar.xz" --strip-components=1
popd

ls -al /restore

dbs=()
while IFS='' read -r line; do dbs+=("$line"); done < <(find "/restore" -mindepth 1 -type d)

for db in "${dbs[@]}"; do
  echo "Recovering $db schema..."
  mysql --defaults-extra-file=<(_mysql_passfile) <"${db}/schema.sql" || true
done

for db in "${dbs[@]}"; do
  echo "Recovering $db data..."
  mysql --defaults-extra-file=<(_mysql_passfile) <"${db}/data.sql" || true
done
