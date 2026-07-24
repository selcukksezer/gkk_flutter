#!/usr/bin/env bash
# F2P player journey smoke — energy, dungeon, quests, reputation
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${ROOT}/reports/player_journey_smoke.json"
SQL="SELECT public.qa_player_journey_f2p();"

mkdir -p "${ROOT}/reports"

echo "==> Player journey smoke (RPC qa_player_journey_f2p)"

RAW=""
if command -v supabase >/dev/null 2>&1; then
  echo "==> via supabase db query --linked"
  supabase db query --linked "$SQL" -o json > "${OUT}.raw" 2>&1 || true
  RAW="$(cat "${OUT}.raw" 2>/dev/null || true)"
fi

if [[ -z "$RAW" ]] && [[ -n "${DATABASE_URL:-}" ]] && command -v psql >/dev/null 2>&1; then
  echo "==> via psql DATABASE_URL"
  psql "${DATABASE_URL}" -At -c "$SQL" > "${OUT}.raw"
  RAW="$(cat "${OUT}.raw")"
fi

if [[ ! -s "${OUT}.raw" ]]; then
  echo "ERROR: Could not run smoke. Apply migration 20260725_020000_qa_player_journey.sql"
  echo "  supabase db push --linked"
  echo "  supabase db query --linked \"SELECT public.qa_player_journey_f2p();\""
  exit 1
fi

python3 - <<'PY' "${OUT}.raw" "${OUT}"
import json, re, sys
raw_path, out_path = sys.argv[1], sys.argv[2]
raw = open(raw_path, encoding='utf-8').read().strip()
data = None
if '"rows"' in raw:
    try:
        wrapper = json.loads(raw[raw.find('{'):raw.rfind('}')+1])
        if wrapper.get('rows'):
            row = wrapper['rows'][0]
            data = row.get('qa_player_journey_f2p') or next(iter(row.values()))
    except json.JSONDecodeError:
        pass
if data is None:
    m = re.search(r'\{.*\}', raw, re.S)
    if not m:
        raise SystemExit(f'Could not parse JSON:\n{raw[:1200]}')
    data = json.loads(m.group(0))
if isinstance(data, str):
    data = json.loads(data)

with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

verdict = data.get('verdict', 'UNKNOWN')
steps = data.get('steps') or []
failed = [s for s in steps if not s.get('pass')]
print('=== Player Journey Smoke ===')
print(f"Verdict: {verdict}")
print(f"Passed: {data.get('passed')}/{data.get('total')}")
for s in steps:
    mark = 'OK' if s.get('pass') else 'FAIL'
    print(f"  [{mark}] {s.get('step')}")
if failed:
    print('\n-- Failures --')
    for s in failed:
        print(json.dumps(s, ensure_ascii=False, indent=2))

sys.exit(0 if verdict == 'PASS' else 1)
PY

echo "==> Report: ${OUT}"
