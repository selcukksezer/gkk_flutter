#!/usr/bin/env bash
# 10k-bot comprehensive smoke: PLAN_11 class passives + PLAN_13 economy/exploit/retention gates
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BOTS="${1:-10000}"
DAYS="${2:-30}"
OUT="${ROOT}/reports/comprehensive_smoke_${BOTS}_${DAYS}d.json"
SQL="SELECT set_config('app.qa_mode', 'true', true); SELECT public.qa_smoke_comprehensive_10k(${BOTS}, ${DAYS}, true);"

mkdir -p "${ROOT}/reports"

echo "==> Comprehensive smoke: ${BOTS} bots, ${DAYS} days"
echo "==> Plans: PLAN_11 (class passives), PLAN_13 (economy/retention/exploits), PLAN_06 (balance proxies)"

if command -v supabase >/dev/null 2>&1; then
  echo "==> via supabase db query --linked"
  supabase db query --linked "SELECT set_config('app.qa_mode', 'true', true); SELECT public.qa_smoke_comprehensive_10k(${BOTS}, ${DAYS}, true);" -o json \
    > "${OUT}.raw" 2>&1 || true
fi

if [[ ! -s "${OUT}.raw" ]] && command -v psql >/dev/null 2>&1 && [[ -n "${DATABASE_URL:-}" ]]; then
  echo "==> via psql DATABASE_URL"
  psql "${DATABASE_URL}" -At -c "$SQL" > "${OUT}.raw"
fi

if [[ ! -s "${OUT}.raw" ]]; then
  echo "ERROR: Could not execute smoke SQL."
  echo "Apply migration 20260629_030000_qa_comprehensive_smoke_10k.sql then run:"
  echo "  SELECT set_config('app.qa_mode','true',true);"
  echo "  SELECT public.qa_smoke_comprehensive_10k(${BOTS}, ${DAYS}, true);"
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
            data = row.get('qa_smoke_comprehensive_10k') or next(iter(row.values()))
    except json.JSONDecodeError:
        pass
if data is None:
    m = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', raw, re.S)
    if not m:
        raise SystemExit(f'Could not parse JSON from output:\n{raw[:800]}')
    data = json.loads(m.group(0))
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

verdict = data.get('verdict', 'UNKNOWN')
failures = data.get('failures') or []
gates = data.get('gates') or {}
p13 = gates.get('plan13') or {}
p11 = gates.get('plan11') or {}

print('=== Comprehensive Smoke 10k ===')
print(f"Verdict: {verdict}")
print(f"Bots: {data.get('bots')} | Days: {data.get('sim_days')} | Events: {data.get('events')}")
print(f"Duration: {data.get('duration_seconds')}s")
print('\n-- PLAN_13 gates --')
for k in (
    'gold_inflation_pct', 'gold_inflation_pass',
    'exploit_success_rate_pct', 'exploit_pass',
    'casual_d30_retention', 'casual_d30_pass',
    'newbie_d30_retention', 'newbie_d30_pass',
):
    if k in p13:
        print(f"  {k}: {p13[k]}")
print('\n-- PLAN_11 passives --')
print(f"  all_pass: {p11.get('all_pass')}")
for t in p11.get('tests') or []:
    mark = 'OK' if t.get('pass') else 'FAIL'
    print(f"  [{mark}] {t.get('test')}")
if failures:
    print('\n-- Failures --')
    for f in failures:
        print(f"  - {f}")
print(f"\nFull report: {out_path}")
if verdict != 'PASS':
    sys.exit(1)
PY

echo "==> Done"
