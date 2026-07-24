#!/usr/bin/env bash
# Full 350-action QA audit — DB RPC layer + sharded integration taps.
#
# Requires one of:
#   - supabase CLI linked to project: supabase db query --linked
#   - DATABASE_URL + psql (direct Postgres connection string)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SHARD_TOTAL="${AUDIT_SHARD_TOTAL:-5}"
OUT="${ROOT}/reports/full_action_audit.json"
RPC_OUT="${ROOT}/reports/full_action_audit_rpc.json"
SHARD_DIR="${ROOT}/reports/full_action_audit_shards"

mkdir -p "${ROOT}/reports" "${SHARD_DIR}"

echo "==> Step 1: Bootstrap QA accounts from DB"
chmod +x scripts/bootstrap_qa_accounts_from_db.sh
./scripts/bootstrap_qa_accounts_from_db.sh 20

if [[ -f .env.qa.accounts ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.qa.accounts && set +a
elif [[ -f .env.qa.local ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.qa.local && set +a
fi

echo "==> Step 2: DB RPC audit (qa_full_action_audit)"
SQL="SELECT public.qa_full_action_audit();"
RPC_RAW="${RPC_OUT}.raw"
RPC_OK=0

if command -v supabase >/dev/null 2>&1; then
  if supabase db query --linked "$SQL" -o json > "${RPC_RAW}" 2>/dev/null; then
    RPC_OK=1
  fi
fi

if [[ "$RPC_OK" == "0" ]] && [[ -n "${DATABASE_URL:-}" ]] && command -v psql >/dev/null 2>&1; then
  if psql "${DATABASE_URL}" -At -c "$SQL" > "${RPC_RAW}"; then
    RPC_OK=1
  fi
fi

if [[ "$RPC_OK" == "0" ]]; then
  echo "ERROR: RPC audit query failed."
  echo "  Set DATABASE_URL (Postgres) or run: supabase link && supabase db query --linked"
  echo "  Migration required: supabase/migrations/20260725_030000_qa_full_action_audit.sql"
  exit 1
fi

if [[ "$RPC_OK" == "1" ]]; then
  python3 - <<'PY' "${RPC_RAW}" "${RPC_OUT}"
import json, re, sys
raw_path, out_path = sys.argv[1], sys.argv[2]
raw = open(raw_path, encoding='utf-8').read().strip()

def parse_payload(text: str):
    if not text:
        return None
    if '|' in text and not text.lstrip().startswith(('[', '{')):
        line = text.splitlines()[0].strip()
        if line.startswith('{') or line.startswith('['):
            text = line
    start = text.find('[') if '[' in text else text.find('{')
    if start < 0:
        return None
    end_char = ']' if text[start] == '[' else '}'
    end = text.rfind(end_char)
    if end < start:
        return None
    try:
        parsed = json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return None
    if isinstance(parsed, dict) and parsed.get('rows'):
        parsed = parsed['rows'][0]
    if isinstance(parsed, list) and parsed:
        parsed = parsed[0]
    if isinstance(parsed, dict):
        data = parsed.get('qa_full_action_audit') or next(iter(parsed.values()), None)
        if isinstance(data, str):
            data = json.loads(data)
        return data
    return None

data = parse_payload(raw)
if data is None:
    m = re.search(r'\{.*\}', raw, re.S)
    if m:
        try:
            data = json.loads(m.group(0))
            if isinstance(data, dict) and 'qa_full_action_audit' in data:
                data = data['qa_full_action_audit']
                if isinstance(data, str):
                    data = json.loads(data)
        except json.JSONDecodeError:
            data = None

if not isinstance(data, dict):
    print('ERROR: could not parse qa_full_action_audit payload', file=sys.stderr)
    sys.exit(1)

with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print('RPC audit verdict:', data.get('verdict'))
PY

echo "==> Step 3: Integration auto_tap shards (${SHARD_TOTAL} jobs)"
INTEGRATION_OK=1
for ((i=0; i<SHARD_TOTAL; i++)); do
  ACCOUNT_IDX=$((i % 20))
  SHARD_FILE="${SHARD_DIR}/shard_${i}.json"
  echo "    shard ${i}/${SHARD_TOTAL} account_index=${ACCOUNT_IDX}"
  set +e
  flutter test integration_test/smoke/full_action_audit_test.dart \
    --dart-define=QA_SKIP_DAILY_REWARD=1 \
    --dart-define=QA_SKIP_TUTORIAL=1 \
    --dart-define=AUDIT_SHARD_INDEX="${i}" \
    --dart-define=AUDIT_SHARD_TOTAL="${SHARD_TOTAL}" \
    --dart-define=QA_ACCOUNT_INDEX="${ACCOUNT_IDX}" \
    --dart-define=QA_ACCOUNTS="${QA_ACCOUNTS:-${QA_TEST_EMAIL}:${QA_TEST_PASSWORD}}" \
    --reporter expanded \
    --timeout 20m 2>&1 | tee "${SHARD_DIR}/shard_${i}.log"
  SHARD_EXIT=${PIPESTATUS[0]}
  set -e
  if [[ "$SHARD_EXIT" != "0" ]]; then
    INTEGRATION_OK=0
  fi
  grep -o 'FULL_ACTION_AUDIT_JSON:.*' "${SHARD_DIR}/shard_${i}.log" | sed 's/^FULL_ACTION_AUDIT_JSON://' > "${SHARD_FILE}" || true
done

echo "==> Step 4: Merge reports -> ${OUT}"
python3 - <<'PY' "${OUT}" "${RPC_OUT}" "${SHARD_DIR}" "${SHARD_TOTAL}"
import json, glob, os, sys
out_path, rpc_path, shard_dir, shard_total = sys.argv[1:5]
shard_total = int(shard_total)
actions = {}
summary = {'total': 350, 'pass': 0, 'fail': 0, 'skip': 0, 'auto_tap': 0, 'rpc': 0}

# RPC layer
if os.path.isfile(rpc_path):
    rpc = json.load(open(rpc_path, encoding='utf-8'))
    for item in rpc.get('actions') or []:
        actions[item['action_id']] = item

# Integration shards
for i in range(shard_total):
    shard_file = os.path.join(shard_dir, f'shard_{i}.json')
    if not os.path.isfile(shard_file) or os.path.getsize(shard_file) == 0:
        continue
    shard = json.loads(open(shard_file, encoding='utf-8').read())
    for item in shard.get('actions') or []:
        aid = item['action_id']
        if item.get('coverage') == 'auto_tap' or item.get('coverage') == 'skip':
            actions[aid] = item
        elif aid not in actions:
            actions[aid] = item

for st in actions.values():
    summary[st.get('coverage', 'auto_tap')] = summary.get(st.get('coverage', 'auto_tap'), 0) + 1
    summary[st.get('status', 'fail')] = summary.get(st.get('status', 'fail'), 0) + 1

missing = 350 - len(actions)
report = {
    'run_id': __import__('datetime').datetime.utcnow().isoformat() + 'Z',
    'test_name': 'full_action_audit',
    'verdict': 'PASS' if summary.get('fail', 0) == 0 and missing == 0 else 'FAIL',
    'total': 350,
    'covered': len(actions),
    'missing': missing,
    'pass': summary.get('pass', 0),
    'fail': summary.get('fail', 0),
    'skip': summary.get('skip', 0),
    'auto_tap': summary.get('auto_tap', 0),
    'rpc': summary.get('rpc', 0),
    'actions': sorted(actions.values(), key=lambda x: x['action_id']),
}
json.dump(report, open(out_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print(json.dumps({k: report[k] for k in ('verdict','pass','fail','skip','auto_tap','rpc','missing')}, indent=2))
PY

if [[ "$INTEGRATION_OK" != "1" ]]; then
  echo "FAIL: one or more integration shards failed"
  exit 1
fi

if [[ -f "${RPC_OUT}" ]]; then
  VERDICT=$(python3 -c "import json; print(json.load(open('${RPC_OUT}'))['verdict'])")
  if [[ "$VERDICT" != "PASS" ]]; then
    echo "FAIL: RPC audit verdict=${VERDICT}"
    exit 1
  fi
fi

echo "==> Done: ${OUT}"
flutter test test/smoke/full_action_coverage_test.dart --reporter expanded
