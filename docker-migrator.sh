#!/bin/bash
set -euo pipefail

ACTION="${1:-}"
SOURCE_DB_URL="${2:-}"
DEST_DB_URL="${3:-}"

EXPORT_DIR="./db_exports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXPORT_FILE="$EXPORT_DIR/db_export_$TIMESTAMP.sql"

mkdir -p "$EXPORT_DIR"

do_export() {
  local url="$1"

  echo "📤 Exporting from $url..."
  docker run --rm \
    -v "$(pwd)/$EXPORT_DIR":/exports \
    --network host \
    postgres:17 \
    pg_dump "$url" -F p -v -f "/exports/$(basename "$EXPORT_FILE")"

  if [ ! -f "$EXPORT_FILE" ]; then
    echo "❌ Export failed: $EXPORT_FILE not found."
    exit 1
  fi

  echo "✅ Export complete: $EXPORT_FILE"
}

do_import() {
  local url="$1"
  local file="$2"

  echo "📥 Importing into $url..."
  docker run --rm \
    -v "$(realpath "$file")":/import.sql \
    --network host \
    postgres:17 \
    psql "$url" -f /import.sql

  echo "✅ Import complete!"
}

# --- DISPATCH ---
if [ -z "$ACTION" ]; then
  echo "Usage: $0 {export <source_db_url>|import <dump_file.sql> <dest_db_url>|migrate <source_db_url> <dest_db_url>}"
  exit 1
fi

case "$ACTION" in
  export)
    if [ -z "$SOURCE_DB_URL" ]; then
      echo "Usage: $0 export <source_db_url>"
      exit 1
    fi
    do_export "$SOURCE_DB_URL"
    ;;
  import)
    if [ -z "$DEST_DB_URL" ] || [ ! -f "$SOURCE_DB_URL" ]; then
      echo "Usage: $0 import <dump_file.sql> <destination_db_url>"
      exit 1
    fi
    do_import "$DEST_DB_URL" "$SOURCE_DB_URL"
    ;;
  migrate)
    if [ -z "$SOURCE_DB_URL" ] || [ -z "$DEST_DB_URL" ]; then
      echo "Usage: $0 migrate <source_db_url> <destination_db_url>"
      exit 1
    fi
    do_export "$SOURCE_DB_URL"
    do_import "$DEST_DB_URL" "$EXPORT_FILE"
    ;;
  *)
    echo "Usage: $0 {export <source_db_url>|import <dump_file.sql> <dest_db_url>|migrate <source_db_url> <dest_db_url>}"
    exit 1
    ;;
esac
