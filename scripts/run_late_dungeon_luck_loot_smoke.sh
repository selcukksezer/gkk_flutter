#!/usr/bin/env bash
# Smoke: max luck / +10 gear vs late dungeon loot inflation.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="${ROOT}/reports/late_dungeon_luck_loot_smoke.json"
mkdir -p "${ROOT}/reports"

echo "==> Late dungeon luck loot smoke"
supabase db query --linked "SELECT public.qa_smoke_late_dungeon_luck_loot();" -o json > "${OUT}.raw" 2>&1 || true

python3 - <<'PY' "${OUT}.raw" "${OUT}"
import json, re, sys
raw = open(sys.argv[1], encoding='utf-8').read().strip()
data = None
if '"rows"' in raw:
    try:
        wrapper = json.loads(raw[raw.find('{'):raw.rfind('}')+1])
        if wrapper.get('rows'):
            row = wrapper['rows'][0]
            data = row.get('qa_smoke_late_dungeon_luck_loot') or next(iter(row.values()))
    except json.JSONDecodeError:
        pass
if data is None:
    m = re.search(r'\{.*\}', raw, re.S)
    if not m:
        raise SystemExit(f'Could not parse:\n{raw[:2000]}')
    data = json.loads(m.group(0))
if isinstance(data, str):
    data = json.loads(data)

json.dump(data, open(sys.argv[2], 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

print('=== Late Dungeon Luck Loot Smoke ===')
print(f"Verdict: {data.get('verdict')}")
print(f"Passed: {data.get('passed')}/{data.get('total')}")
kf = data.get('key_finding') or {}
print('KEY:', json.dumps(kf, ensure_ascii=False))
for t in data.get('tests') or []:
    mark = 'OK' if t.get('pass') else 'FAIL'
    print(f"  [{mark}] {t.get('area')}: {t.get('test')}")
    d = t.get('detail') or {}
    if t.get('test') == 'late_dungeon_equipment_drop_not_excessive_under_real_luck':
        print(f"         excessive={d.get('excessive_cells')} softcapHits={d.get('softcap_hits_095')}")
        for r in d.get('sample_rates') or []:
            print(f"           {r.get('profile')}@{r.get('dungeon')}: "
                  f"base={r.get('base_equipment_drop')} → eff={r.get('eff_equipment_drop')} "
                  f"(/100wins={r.get('expected_equip_per_100_wins')})")
    elif t.get('test') == 'worst_real_late_boss_equip_drop_le_049':
        print(f"         {d.get('verdict_tr')}")
        print(f"         eff={d.get('eff')} items/100={d.get('items_per_100_wins')}")
    elif t.get('test') == 'loot_luck_uses_users_luck_not_equipped_items':
        print(f"         equipLuckSum={d.get('equip_max_luck_sum_8slot')} "
              f"combatPowerFromLuck+10={d.get('equip_luck_power_at_plus10_combat_only')}")
        print(f"         {d.get('note')}")
    else:
        slim = {k:v for k,v in d.items() if k not in ('dungeons','sample_rates','hypo_sample','rates')}
        if slim:
            print(f"         {json.dumps(slim, ensure_ascii=False)}")

failed = [t for t in (data.get('tests') or []) if not t.get('pass')]
if failed:
    print('\n-- Failures --')
    for t in failed:
        print(json.dumps(t, ensure_ascii=False, indent=2))
sys.exit(0 if data.get('verdict') == 'PASS' else 1)
PY
