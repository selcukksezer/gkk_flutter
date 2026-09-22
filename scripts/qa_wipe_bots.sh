#!/usr/bin/env bash
# Wipe AI live-play bots (launch cleanup).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "==> qa_wipe_live_play_bots()"
SQL="SELECT set_config('app.qa_mode','true',true); SELECT public.qa_wipe_live_play_bots();"
if command -v supabase >/dev/null 2>&1; then
  supabase db query --linked "$SQL" -o json
elif [[ -n "${DATABASE_URL:-}" ]] && command -v psql >/dev/null 2>&1; then
  psql "${DATABASE_URL}" -At -c "$SQL"
else
  echo "ERROR: need supabase CLI or DATABASE_URL+psql"
  exit 1
fi
echo "==> Done. Archive reports/ before launch DB reset."
