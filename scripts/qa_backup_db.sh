#!/usr/bin/env bash
# QA pre-simulation backup — full pg_dump of public + game schemas with sha256.
# Plan ref: PLAN_13 §1.2 (backup scope), §10 (deliverables), §11 step 2.
#
# Required deliverable before ANY bot run: backups/<TS>/full_db.dump + .sha256
#
# Usage:
#   SUPABASE_DB_URL='postgresql://postgres:...@db.<ref>.supabase.co:5432/postgres' \
#     bash scripts/qa_backup_db.sh
#
# Or put SUPABASE_DB_URL in .env.qa.local. Use the SERVICE-ROLE / direct DB
# connection string (Project Settings → Database → Connection string).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env.qa.local ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.qa.local && set +a
fi

DB_URL="${SUPABASE_DB_URL:-}"
if [[ -z "$DB_URL" ]]; then
  echo "ERROR: SUPABASE_DB_URL is not set (env or .env.qa.local)." >&2
  echo "       Use the direct Postgres connection string for the STAGING branch." >&2
  exit 1
fi

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "ERROR: pg_dump not found. Install libpq:" >&2
  echo "       brew install libpq && export PATH=\"/opt/homebrew/opt/libpq/bin:\$PATH\"" >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="backups/${TS}"
mkdir -p "$OUT_DIR"

DUMP_FILE="${OUT_DIR}/full_db.dump"
SCHEMA_FILE="${OUT_DIR}/public_game_schema.sql"

echo "==> Full custom-format dump (all schemas) → ${DUMP_FILE}"
pg_dump --format=custom --no-owner --no-privileges \
  --file="$DUMP_FILE" "$DB_URL"

echo "==> Plain SQL dump (public + game schemas) → ${SCHEMA_FILE}"
pg_dump --format=plain --no-owner --no-privileges \
  --schema=public --schema=game \
  --file="$SCHEMA_FILE" "$DB_URL"

echo "==> Computing sha256 checksums"
( cd "$OUT_DIR" && shasum -a 256 ./* > SHA256SUMS.txt )

echo "==> Backup complete:"
ls -lh "$OUT_DIR"
cat "${OUT_DIR}/SHA256SUMS.txt"

echo
echo "Restore drill (staging clone) before any Phase 2+ work:"
echo "  pg_restore --clean --if-exists --no-owner -d \"\$STAGING_DB_URL\" ${DUMP_FILE}"
