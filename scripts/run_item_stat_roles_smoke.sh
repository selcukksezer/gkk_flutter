#!/usr/bin/env bash
# Smoke: item role extras (catalog diversity + inventory join + power).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${ROOT}/reports/item_stat_roles_smoke.json"
SQL="SELECT public.qa_smoke_item_stat_roles();"

mkdir -p "${ROOT}/reports"

echo "==> Item stat roles smoke (RPC qa_smoke_item_stat_roles)"

RAW=""
if command -v supabase >/dev/null 2>&1; then
  echo "==> via supabase db query --linked"
  supabase db query --linked "$SQL" -o json > "${OUT}.raw" 2>&1 || true
  RAW="$(cat "${OUT}.raw" 2>/dev/null || true)"
fi

if [[ -z "$RAW" || "$RAW" == *"Could not"* || "$RAW" == *"ERROR"* ]]; then
  echo "==> fallback: MCP/direct note — trying apply then query"
fi

if [[ ! -s "${OUT}.raw" ]]; then
  echo "ERROR: Could not run smoke. Apply migration then:"
  echo "  supabase db query --linked \"SELECT public.qa_smoke_item_stat_roles();\""
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
            data = row.get('qa_smoke_item_stat_roles') or next(iter(row.values()))
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
print('=== Item Stat Roles Smoke ===')
print(f"Verdict: {verdict}")
print(f"Passed: {data.get('passed')}/{data.get('total')}")
for t in tests:
    mark = 'OK' if t.get('pass') else 'FAIL'
    print(f"  [{mark}] {t.get('area')}: {t.get('test')}")
    detail = t.get('detail') or {}
    if detail:
        print(f"         {json.dumps(detail, ensure_ascii=False)}")
if failed:
    print('\n-- Failures --')
    for t in failed:
        print(json.dumps(t, ensure_ascii=False, indent=2))

sys.exit(0 if verdict == 'PASS' else 1)
PY
