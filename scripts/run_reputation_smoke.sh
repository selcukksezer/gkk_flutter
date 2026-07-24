#!/usr/bin/env bash
# Smoke test for reputation overview + shop + purchase
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${ROOT}/reports/reputation_smoke.json"
SQL="SELECT public.qa_smoke_reputation();"

mkdir -p "${ROOT}/reports"

echo "==> Reputation smoke (RPC qa_smoke_reputation)"

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
  echo "ERROR: Could not run smoke. Apply migration 20260725_010000_qa_smoke_reputation.sql"
  echo "  supabase db push --linked"
  echo "  supabase db query --linked \"SELECT public.qa_smoke_reputation();\""
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
            data = row.get('qa_smoke_reputation') or next(iter(row.values()))
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
print('=== Reputation Smoke ===')
print(f"Verdict: {verdict}")
print(f"Passed: {data.get('passed')}/{data.get('total')}")
for t in tests:
    mark = 'OK' if t.get('pass') else 'FAIL'
    print(f"  [{mark}] {t.get('area')}: {t.get('test')}")
if failed:
    print('\n-- Failures --')
    for t in failed:
        print(json.dumps(t, ensure_ascii=False, indent=2))

sys.exit(0 if verdict == 'PASS' else 1)
PY

echo "==> Report: ${OUT}"
