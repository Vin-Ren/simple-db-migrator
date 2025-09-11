#!/bin/bash

# Usage: ./export.sh "postgres://user:password@host:port/dbname"

if [ -z "$1" ]; then
  echo "Usage: $0 <database_url>"
  exit 1
fi

DATABASE_URL="$1"
EXPORT_DIR="./db_exports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXPORT_FILE="$EXPORT_DIR/db_export_$TIMESTAMP.sql"

# Ensure export directory exists
mkdir -p "$EXPORT_DIR"

# Extract password from URL for PGPASSWORD
PGPASSWORD=$(echo $DATABASE_URL | sed -E 's|.*://[^:]+:([^@]+)@.*|\1|')

# Export using pg_dump
PGPASSWORD=$PGPASSWORD pg_dump "$DATABASE_URL" -F p -v -f "$EXPORT_FILE"

# Check result
if [ $? -eq 0 ]; then
  echo "✅ Export complete: $EXPORT_FILE"
else
  echo "❌ Export failed."
  exit 1
fi
