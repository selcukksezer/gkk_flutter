#!/usr/bin/env bash
# Smoke test for bugfix batch (bank 5gem/slot, deposit, equip, box, weekly LB)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${ROOT}/reports/bugfix_batch_smoke.json"
LOG="${ROOT}/.cursor/debug-02eb2a.log"
SQL="SELECT public.qa_smoke_bugfix_batch();"

mkdir -p "${ROOT}/reports" "${ROOT}/.cursor"

echo "==> Bugfix batch smoke (RPC qa_smoke_bugfix_batch)"

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
  echo "ERROR: Could not run smoke. Apply migration 20260721_240000_qa_bugfix_batch_smoke.sql"
  echo "  supabase db query --linked \"SELECT set_config('app.qa_mode','true',true); SELECT public.qa_smoke_bugfix_batch();\""
  exit 1
fi

python3 - <<'PY' "${OUT}.raw" "${OUT}" "${LOG}"
import json, re, sys, time
raw_path, out_path, log_path = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(raw_path, encoding='utf-8').read().strip()
data = None
if '"rows"' in raw:
    try:
        wrapper = json.loads(raw[raw.find('{'):raw.rfind('}')+1])
        if wrapper.get('rows'):
            row = wrapper['rows'][0]
            data = row.get('qa_smoke_bugfix_batch') or next(iter(row.values()))
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
tests = data.get('tests') or []
failed = [t for t in tests if not t.get('pass')]
print('=== Bugfix Batch Smoke ===')
print(f"Verdict: {verdict}")
print(f"Passed: {data.get('passed')}/{data.get('total')}")
for t in tests:
    mark = 'OK' if t.get('pass') else 'FAIL'
    print(f"  [{mark}] {t.get('area')}: {t.get('test')}")
if failed:
    print('\n-- Failures --')
    for t in failed:
        print(json.dumps(t, ensure_ascii=False, indent=2))

# NDJSON debug log entry
entry = {
    'sessionId': '02eb2a',
    'timestamp': int(time.time() * 1000),
    'location': 'scripts/run_bugfix_batch_smoke.sh',
    'message': 'bugfix_batch_smoke_complete',
    'data': {'verdict': verdict, 'passed': data.get('passed'), 'total': data.get('total'), 'failed_tests': [t.get('test') for t in failed]},
    'hypothesisId': 'SMOKE',
    'runId': 'bugfix-batch'
}
with open(log_path, 'a', encoding='utf-8') as lf:
    lf.write(json.dumps(entry, ensure_ascii=False) + '\n')

sys.exit(0 if verdict == 'PASS' else 1)
PY

echo "==> Report: ${OUT}"
echo "==> Debug log: ${LOG}"
