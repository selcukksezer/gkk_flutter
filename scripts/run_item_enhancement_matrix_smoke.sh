#!/usr/bin/env bash
# Exhaustive enhancement matrix smoke (+0..+10 all gear + full sets).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${ROOT}/reports/item_enhancement_matrix_smoke.json"
SQL="SELECT public.qa_smoke_item_enhancement_matrix();"

mkdir -p "${ROOT}/reports"

echo "==> Item enhancement matrix smoke"

if ! command -v supabase >/dev/null 2>&1; then
  echo "ERROR: supabase CLI required"
  exit 1
fi

supabase db query --linked "$SQL" -o json > "${OUT}.raw" 2>&1 || true

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
            data = row.get('qa_smoke_item_enhancement_matrix') or next(iter(row.values()))
    except json.JSONDecodeError:
        pass
if data is None:
    m = re.search(r'\{.*\}', raw, re.S)
    if not m:
        raise SystemExit(f'Could not parse JSON:\n{raw[:2000]}')
    data = json.loads(m.group(0))
if isinstance(data, str):
    data = json.loads(data)

with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

verdict = data.get('verdict', 'UNKNOWN')
tests = data.get('tests') or []
failed = [t for t in tests if not t.get('pass')]
print('=== Item Enhancement Matrix Smoke ===')
print(f"Verdict: {verdict}")
print(f"Passed: {data.get('passed')}/{data.get('total')}")
print(f"Gear items: {data.get('gear_items')}  Combos: {data.get('combinations_checked')}")
print(f"Mult table: {json.dumps(data.get('enhancement_mult_table'), ensure_ascii=False)}")
for t in tests:
    mark = 'OK' if t.get('pass') else 'FAIL'
    print(f"  [{mark}] {t.get('area')}: {t.get('test')}")
    detail = t.get('detail') or {}
    # Compact print for huge details
    if t.get('test') == 'best_power_set_each_rarity_plus0_and_plus10':
        for s in detail.get('sets') or []:
            print(f"         set {s.get('rarity')}: +0={s.get('set_power_plus0')}  +10={s.get('set_power_plus10')}  "
                  f"x{s.get('set_multiplier')}  luckShare={s.get('set_luck_share_pct')}%")
    elif t.get('test') == 'max_luck_full_sets_at_plus10':
        for s in detail.get('sets') or []:
            print(f"         luck-set {s.get('rarity')}: +10={s.get('set_plus10')}  luckShare={s.get('luck_share_pct')}%")
    elif t.get('test') == 'luck_share_audit_ge_55pct':
        print(f"         luck_heavy={detail.get('luck_heavy_items')}  warn={detail.get('warn')}")
        for it in (detail.get('top_luck_share_items') or [])[:8]:
            print(f"           {it.get('id')}: luckShare={it.get('luck_share_pct')}%  "
                  f"luck={it.get('luck')} base={it.get('base_power')} +10={it.get('power_plus10')}")
    elif t.get('test') == 'common_weapon_roles_full_plus_curve':
        by = {}
        for row in detail.get('curves') or []:
            by.setdefault(row['id'], []).append(row)
        for iid, rows in by.items():
            curve = ','.join(str(r['power']) for r in rows)
            print(f"         {iid}: [{curve}]")
    else:
        slim = {k: v for k, v in detail.items() if k not in ('curves', 'sets', 'top_luck_share_items', 'pieces')}
        if slim:
            print(f"         {json.dumps(slim, ensure_ascii=False)}")

if failed:
    print('\n-- Failures --')
    for t in failed:
        print(json.dumps(t, ensure_ascii=False, indent=2))

sys.exit(0 if verdict == 'PASS' else 1)
PY
