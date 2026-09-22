#!/usr/bin/env bash
# Seed AI live-play bots (default 300).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
COUNT="${1:-300}"
echo "==> qa_seed_live_play_bots(${COUNT})"
SQL="SELECT set_config('app.qa_mode','true',true); SELECT public.qa_seed_live_play_bots(${COUNT});"
if command -v supabase >/dev/null 2>&1; then
  supabase db query --linked "$SQL" -o json
elif [[ -n "${DATABASE_URL:-}" ]] && command -v psql >/dev/null 2>&1; then
  psql "${DATABASE_URL}" -At -c "$SQL"
else
  echo "ERROR: need supabase CLI or DATABASE_URL+psql"
  exit 1
fi
echo "==> password: QaLivePlay300!  email: qa_bot_NNN@sim.local"
