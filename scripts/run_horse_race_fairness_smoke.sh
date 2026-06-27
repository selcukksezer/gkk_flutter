#!/usr/bin/env bash
# 500-run horse race fairness smoke (gold + gems payout simulation)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RUNS="${1:-500}"
OUT="${ROOT}/reports/horse_race_fairness_smoke_${RUNS}.json"

mkdir -p "${ROOT}/reports"

if command -v supabase >/dev/null 2>&1; then
  echo "==> Running qa_smoke_horse_race_fairness(${RUNS}) via supabase sql"
  supabase db execute --linked \
    --sql "SELECT public.qa_smoke_horse_race_fairness(${RUNS});" \
    > "${OUT}.raw" 2>&1 || true
fi

if [[ ! -s "${OUT}.raw" ]] && command -v psql >/dev/null 2>&1 && [[ -n "${DATABASE_URL:-}" ]]; then
  echo "==> Running via psql DATABASE_URL"
  psql "${DATABASE_URL}" -At -c "SELECT public.qa_smoke_horse_race_fairness(${RUNS});" > "${OUT}.raw"
fi

if [[ ! -s "${OUT}.raw" ]]; then
  echo "ERROR: Could not execute smoke SQL."
  echo "Apply migration 20260619_030000_horse_race_smoke_simulation.sql then run:"
  echo "  SELECT public.qa_smoke_horse_race_fairness(${RUNS});"
  exit 1
fi

python3 - <<'PY' "${OUT}.raw" "${OUT}"
import json, re, sys
raw_path, out_path = sys.argv[1], sys.argv[2]
raw = open(raw_path, encoding='utf-8').read().strip()
# supabase/psql may wrap in quotes or include extra rows
m = re.search(r'\{.*\}', raw, re.S)
if not m:
    raise SystemExit(f'Could not parse JSON from output:\n{raw[:500]}')
data = json.loads(m.group(0))
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

fc = data.get('fairness_check', {})
print('=== Horse Race Fairness Smoke ===')
print(f"Runs: {data.get('runs')}")
print(f"Verdict: {fc.get('verdict')}")
print(f"Lowest gold mult wins: {fc.get('lowest_gold_mult_wins')} ({fc.get('lowest_gold_mult_win_pct')}%)")
print(f"Lowest gem mult wins: {fc.get('lowest_gem_mult_wins')} ({fc.get('lowest_gem_mult_win_pct')}%)")
for key in (
    'gold_lowest_mult_strategy',
    'gold_highest_mult_strategy',
    'gems_lowest_mult_strategy',
    'gems_highest_mult_strategy',
):
    s = data.get(key, {})
    print(f"\n[{key}]")
    print(f"  wins/losses: {s.get('wins')}/{s.get('losses')} ({s.get('win_rate_pct')}%)")
    print(f"  wagered: {s.get('total_wagered')} payout: {s.get('total_payout')} net: {s.get('net_profit')} RTP: {s.get('rtp_pct')}%")
print(f"\nFull report: {out_path}")
PY

echo "==> Done"
