#!/bin/bash

# Usage: ./import.sh "postgres://user:password@host:port/newdbname" "path/to/file.sql"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <target_database_url> <sql_file>"
  exit 1
fi

DATABASE_URL="$1"
SQL_FILE="$2"

if [ ! -f "$SQL_FILE" ]; then
  echo "❌ File not found: $SQL_FILE"
  exit 1
fi

# Extract password from URL
PGPASSWORD=$(echo $DATABASE_URL | sed -E 's|.*://[^:]+:([^@]+)@.*|\1|')

# Run import
PGPASSWORD=$PGPASSWORD psql "$DATABASE_URL" -f "$SQL_FILE"

# Check result
if [ $? -eq 0 ]; then
  echo "✅ Import successful into $DATABASE_URL"
else
  echo "❌ Import failed."
  exit 1
fi
