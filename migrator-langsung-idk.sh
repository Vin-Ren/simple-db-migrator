#!/bin/bash

set -e

SOURCE_DB_URL="$1"
DEST_DB_URL="$2"

if [ -z "$SOURCE_DB_URL" ] || [ -z "$DEST_DB_URL" ]; then
  echo "Usage: ./migrate.sh <source_db_url> <destination_db_url>"
  exit 1
fi

EXPORT_DIR="./db_exports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXPORT_FILE="$EXPORT_DIR/db_export_$TIMESTAMP.sql"

mkdir -p "$EXPORT_DIR"

# Function to parse URL
parse_db_url() {
  local url="$1"
  proto="$(echo "$url" | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  url_wo_proto="${url/$proto/}"
  userpass_hostport_db="$(echo "$url_wo_proto" | cut -d'/' -f1)"
  dbname="$(echo "$url_wo_proto" | cut -d'/' -f2)"
  userpass="$(echo "$userpass_hostport_db" | cut -d'@' -f1)"
  hostport="$(echo "$userpass_hostport_db" | cut -d'@' -f2)"
  dbuser="$(echo "$userpass" | cut -d':' -f1)"
  dbpass="$(echo "$userpass" | cut -d':' -f2)"
  dbhost="$(echo "$hostport" | cut -d':' -f1)"
  dbport="$(echo "$hostport" | cut -d':' -f2)"

  echo "$dbuser" "$dbpass" "$dbhost" "$dbport" "$dbname"
}

# --- EXPORT ---
read SRC_USER SRC_PASS SRC_HOST SRC_PORT SRC_NAME < <(parse_db_url "$SOURCE_DB_URL")

echo "📤 Exporting from $SOURCE_DB_URL..."

docker run --rm \
  -e PGPASSWORD="$SRC_PASS" \
  -v "$(pwd)/$EXPORT_DIR":/exports \
  postgres:17 \
  pg_dump -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -d "$SRC_NAME" \
    -F p -v -f "/exports/$(basename "$EXPORT_FILE")"

if [ ! -f "$EXPORT_FILE" ]; then
  echo "❌ Export failed: $EXPORT_FILE not found."
  exit 1
fi

echo "✅ Export complete: $EXPORT_FILE"

# --- IMPORT ---
read DST_USER DST_PASS DST_HOST DST_PORT DST_NAME < <(parse_db_url "$DEST_DB_URL")

echo "📥 Importing into $DEST_DB_URL..."

docker run --rm \
  -e PGPASSWORD="$DST_PASS" \
  -v "$(realpath "$EXPORT_FILE")":/import.sql \
  postgres:17 \
  psql -h "$DST_HOST" -p "$DST_PORT" -U "$DST_USER" -d "$DST_NAME" -f /import.sql

echo "✅ Import complete!"