#!/usr/bin/env bash
# Run AI live-play swarm (default bots 1..300). Writes reports/ai_swarm_300_<ts>/
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FROM="${AI_FROM:-1}"
TO="${AI_TO:-${AI_BOTS:-300}}"
WORKERS="${AI_WORKERS:-1}"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${ROOT}/reports/ai_swarm_300_${TS}"
mkdir -p "${OUT_DIR}/bots"

echo "==> AI swarm bots ${FROM}..${TO} workers=${WORKERS}"
echo "==> Out: ${OUT_DIR}"

run_range() {
  local f="$1" t="$2" shard="$3"
  local raw="${OUT_DIR}/swarm_${shard}.raw"
  local sql="SELECT set_config('app.qa_mode','true',true); SELECT public.qa_live_play_swarm(${f}, ${t});"
  echo "==> shard ${shard}: ${f}-${t}"
  if command -v supabase >/dev/null 2>&1; then
    supabase db query --linked "$sql" -o json > "${raw}" 2>&1 || true
  elif [[ -n "${DATABASE_URL:-}" ]] && command -v psql >/dev/null 2>&1; then
    psql "${DATABASE_URL}" -At -c "$sql" > "${raw}"
  else
    echo "ERROR: need supabase or DATABASE_URL" >&2
    exit 1
  fi
}

if [[ "${WORKERS}" -le 1 ]]; then
  run_range "${FROM}" "${TO}" "0"
else
  TOTAL=$((TO - FROM + 1))
  CHUNK=$(( (TOTAL + WORKERS - 1) / WORKERS ))
  pids=()
  for ((w=0; w<WORKERS; w++)); do
    s=$((FROM + w * CHUNK))
    e=$((s + CHUNK - 1))
    if [[ "$s" -gt "$TO" ]]; then break; fi
    if [[ "$e" -gt "$TO" ]]; then e=$TO; fi
    run_range "$s" "$e" "$w" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do wait "$pid" || true; done
fi

python3 - <<'PY' "${OUT_DIR}" "${FROM}" "${TO}"
import json, re, sys, glob, os
out_dir, fr, to = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
raws = sorted(glob.glob(os.path.join(out_dir, 'swarm_*.raw')))
if not raws:
    raise SystemExit('no swarm raw files')

def parse_raw(path):
    raw = open(path, encoding='utf-8').read()
    data = None
    if '"rows"' in raw:
        try:
            wrapper = json.loads(raw[raw.find('{'):raw.rfind('}')+1])
            if wrapper.get('rows'):
                row = wrapper['rows'][0]
                data = row.get('qa_live_play_swarm') or next(iter(row.values()))
        except Exception:
            pass
    if data is None:
        m = re.search(r'\{.*\}', raw, re.S)
        if not m:
            raise SystemExit(f'parse fail: {path}\n{raw[:500]}')
        data = json.loads(m.group(0))
    if isinstance(data, str):
        data = json.loads(data)
    return data

shards = [parse_raw(p) for p in raws]
merged = {
    'run_id': shards[0].get('run_id'),
    'from': fr,
    'to': to,
    'bots_pass': 0,
    'bots_fail': 0,
    'bots_total': 0,
    'bots': [],
    'coverage_by_goal': {},
    'verdict': 'PASS',
}
for s in shards:
    merged['bots_pass'] += int(s.get('bots_pass') or 0)
    merged['bots_fail'] += int(s.get('bots_fail') or 0)
    merged['bots_total'] += int(s.get('bots_total') or 0)
    merged['bots'].extend(s.get('bots') or [])
    for gid, counts in (s.get('coverage_by_goal') or {}).items():
        slot = merged['coverage_by_goal'].setdefault(gid, {})
        for st, n in (counts or {}).items():
            slot[st] = slot.get(st, 0) + int(n)

if merged['bots_fail']:
    merged['verdict'] = 'FAIL'

# registry completeness markers (Dart registry size mirrored)
REGISTRY = [
    'legal_accept','daily_reward_claim','character_allocate_stat','inventory_open',
    'inventory_equip_item','dungeon_list_load','dungeon_enter_confirm','dungeon_attack_win',
    'enhancement_forge','enhancement_equip_upgraded','market_browse','market_search',
    'market_list_item','market_buy_listing','shop_buy_qa_gem_pack','friends_send_request',
    'chat_global_send','chat_dm_send','chat_dm_reply','guild_create_or_join',
    'guild_monument_donate','guild_war_hub','quests_list','reputation_overview',
]
missing = [g for g in REGISTRY if g not in merged['coverage_by_goal']]
merged['goals_not_in_sql_marathon'] = [g for g in [
    'character_stats_view','codex_dashboard','pvp_dashboard_load','trade_initiate',
    'crafting_start_queue','horse_race_bet','bank_deposit','facilities_start_job',
] if g not in merged['coverage_by_goal']]
merged['registry_goal_count'] = 60
merged['mesh'] = {'botCount': to - fr + 1, 'guildSize': 10}

summary_path = os.path.join(out_dir, 'summary.json')
with open(summary_path, 'w', encoding='utf-8') as f:
    json.dump(merged, f, ensure_ascii=False, indent=2)

# MD reports
lines = ['# Coverage by goal', '', '| Goal | PASS | FAIL | SKIP |', '|------|-----:|-----:|-----:|']
for gid in sorted(merged['coverage_by_goal']):
    c = merged['coverage_by_goal'][gid]
    lines.append(f"| `{gid}` | {c.get('PASS',0)} | {c.get('FAIL',0)} | {c.get('SKIP',0)} |")
open(os.path.join(out_dir, 'coverage_by_goal.md'), 'w', encoding='utf-8').write('\n'.join(lines)+'\n')

bugs = ['# BUGS', '']
fails = [b for b in merged['bots'] if b.get('verdict')=='FAIL']
bugs.append(f"Failed bots: {len(fails)}")
for b in fails:
    bugs.append(f"- bot {b.get('bot_index')}: failed={b.get('failed')}")
if not fails:
    bugs.append('_No FAIL bots._')
open(os.path.join(out_dir, 'BUGS.md'), 'w', encoding='utf-8').write('\n'.join(bugs)+'\n')

rapor = f"""# AI Live-Play Swarm Raporu

**Verdict:** `{merged['verdict']}`
**Bots:** {merged['bots_pass']} PASS / {merged['bots_fail']} FAIL / {merged['bots_total']} total
**Range:** {fr}–{to}

Detay: `coverage_by_goal.md`, `summary.json`.
Launch wipe: `scripts/qa_wipe_bots.sh` + WIPE_CHECKLIST.md
"""
open(os.path.join(out_dir, 'live_play_rapor.md'), 'w', encoding='utf-8').write(rapor)
with open(os.path.join(out_dir, 'coverage_matrix.json'), 'w', encoding='utf-8') as f:
    json.dump(merged['coverage_by_goal'], f, ensure_ascii=False, indent=2)
with open(os.path.join(out_dir, 'social_mesh.json'), 'w', encoding='utf-8') as f:
    json.dump(merged['mesh'], f, ensure_ascii=False, indent=2)

print('=== AI Live-Play Swarm ===')
print(f"Verdict: {merged['verdict']}")
print(f"Bots: {merged['bots_pass']}/{merged['bots_total']} PASS")
print(f"Report: {summary_path}")
sys.exit(0 if merged['verdict']=='PASS' else 1)
PY

echo "==> Done: ${OUT_DIR}"
