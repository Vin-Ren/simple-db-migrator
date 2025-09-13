#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]
then
  echo "Usage: $0 <path_to_sql_file>"
  exit 1
fi

SQL_FILE="$1"
if [[ ! -f "$SQL_FILE" ]]; then
  echo "❌ SQL file not found: $SQL_FILE"
  exit 1
fi

TS=$(date +"%Y%m%d_%H%M%S")
OUTDIR="exports/export_$TS"
mkdir -p "$OUTDIR"

PG_CONTAINER="pg_tmp_$TS"
PY_CONTAINER="py_tmp_$TS"

cleanup() {
  echo "🧹 Cleaning up..."
  docker rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true
  docker rm -f "$PY_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "🚀 Starting temporary Postgres 17..."
docker run -d --name "$PG_CONTAINER" \
  -e POSTGRES_PASSWORD=pass \
  -e POSTGRES_USER=user \
  -e POSTGRES_DB=db \
  postgres:17 > /dev/null

echo "⏳ Waiting for Postgres..."
until docker exec "$PG_CONTAINER" pg_isready -U user -d db > /dev/null 2>&1; do
  sleep 1
done

echo "📥 Restoring dump into Postgres..."
docker cp "$SQL_FILE" "$PG_CONTAINER:/tmp/dump.sql"
docker exec -u postgres "$PG_CONTAINER" psql -U user -d db -f /tmp/dump.sql > /dev/null

echo "📤 Exporting tables..."
docker run --rm --name "$PY_CONTAINER" \
  --link "$PG_CONTAINER":pg \
  -v "$(pwd)/$OUTDIR":/out \
  python:3.11-slim bash -c "
    set -e
    pip install --quiet psycopg2-binary openpyxl > /dev/null
    python - <<'PYCODE'
import psycopg2, csv, json, os
from openpyxl import Workbook
from datetime import datetime, date, time, timedelta

conn = psycopg2.connect(host='pg', dbname='db', user='user', password='pass')
cur = conn.cursor()

cur.execute(\"SELECT tablename FROM pg_tables WHERE schemaname='public'\")
tables = [r[0] for r in cur.fetchall()]

def serialize(obj):
    if isinstance(obj, (datetime, date, time)):
        return obj.isoformat()
    if isinstance(obj, timedelta):
        return str(obj.total_seconds())
    return str(obj)

wb = Workbook()
wb.remove(wb.active)

for table in tables:
    cur.execute(f'SELECT * FROM \"{table}\"')
    rows = cur.fetchall()
    cols = [desc[0] for desc in cur.description]

    with open(f'/out/{table}.json', 'w', encoding='utf-8') as f:
        json.dump([dict(zip(cols, map(serialize, r))) for r in rows], f, ensure_ascii=False, indent=2)

    with open(f'/out/{table}.csv', 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(cols)
        writer.writerows(rows)

    ws = wb.create_sheet(title=table[:31])
    ws.append(cols)
    for r in rows:
        ws.append([serialize(v) for v in r])

wb.save('/out/_export.xlsx')
cur.close()
conn.close()
PYCODE
"

echo "✅ Export complete: $OUTDIR"
