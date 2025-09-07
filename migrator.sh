#!/bin/bash

set -e  # Exit on error

SOURCE_DB_URL="$1"
DEST_DB_URL="$2"

if [ -z "$SOURCE_DB_URL" ] || [ -z "$DEST_DB_URL" ]; then
  echo "Usage: ./migrate.sh <source_db_url> <destination_db_url>"
  exit 1
fi

EXPORT_OUTPUT=$(./export.sh "$SOURCE_DB_URL")
EXPORT_FILE=$(echo "$EXPORT_OUTPUT" | grep "✅ Export complete:" | cut -d ':' -f2- | xargs)

if [ -z "$EXPORT_FILE" ] || [ ! -f "$EXPORT_FILE" ]; then
  echo "❌ Export failed or file not found."
  exit 1
fi

echo "📥 Importing into destination database from $EXPORT_FILE..."
./import.sh "$DEST_DB_URL" "$EXPORT_FILE"

echo "✅ Import complete!"
