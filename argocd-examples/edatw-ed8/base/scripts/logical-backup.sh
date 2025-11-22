#!/usr/bin/env bash
set -euo pipefail

_mysql_passfile() {
  cat <<EOF
  [client]
  host=ed8.edatw-ed8.svc.cluster.local
  user="${ED8_USER}"
  password="${ED8_PASSWORD}"
EOF
}

dbs=()
while IFS='' read -r line; do dbs+=("$line"); done < <(mysql --defaults-extra-file=<(_mysql_passfile) -Bse "show databases")

TMPDIR="$(mktemp -d)"
DATE="$(date "+%Y%m%d")"
ZIPDIR="$TMPDIR/$DATE"
pushd "$TMPDIR"

for db in "${dbs[@]}"; do
  if [[ $db == "mysql" ]]; then
    continue
  elif [[ $db == "information_schema" ]]; then
    continue
  elif [[ $db == "performance_schema" ]]; then
    continue
  elif [[ $db == "sys" ]]; then
    continue
  fi

  mkdir -p "$ZIPDIR/$db"
  echo "Backup $db schema..."
  mysqldump --defaults-extra-file=<(_mysql_passfile) -u "${ED8_USER}" --no-data --skip-add-drop-table --skip-add-locks --skip-lock-tables --databases "$db" >"$ZIPDIR/$db/schema.sql"
  echo "Backup $db data..."
  mysqldump --defaults-extra-file=<(_mysql_passfile) -u "${ED8_USER}" --no-create-info --skip-add-drop-table --skip-add-locks --skip-lock-tables --databases "$db" >"$ZIPDIR/$db/data.sql"
done

echo "Cleanup exist backup..."
DIR="/backups/$DATE"
rm -rf "$DIR" || true
echo "Create backup..."
rm -rf "/backups/$DATE.tar.xz" || true
rm -rf "/backups/latest.tar.xz" || true
tar -czf "/backups/$DATE.tar.xz" $DATE
cp "/backups/$DATE.tar.xz" "/backups/latest.tar.xz"

popd
