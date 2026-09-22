#!/usr/bin/env bash
# Gameplay journey smoke on physical device / simulator.
# UI: integration_test/journeys/full_journey_smoke_test.dart (F2P flows, not route matrix)
# Optional DB: qa_player_journey_f2p RPC when supabase/psql available.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEVICE_ID="${DEVICE_ID:-00008110-0001206C2107801E}"
OUT="${ROOT}/reports/full_journey_device.json"
LOG="${ROOT}/reports/full_journey_device.log"
RUN_DB="${RUN_DB_SMOKE:-1}"

mkdir -p "${ROOT}/reports"

if [[ -f .env.qa.accounts ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.qa.accounts && set +a
fi
if [[ -f .env.qa.local ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.qa.local && set +a
fi

EMAIL="${QA_TEST_EMAIL:-}"
PASSWORD="${QA_TEST_PASSWORD:-}"

if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
  echo "ERROR: QA_TEST_EMAIL / QA_TEST_PASSWORD required (.env.qa.local or .env.qa.accounts)"
  exit 1
fi

DEFINE_ARGS=(
  --dart-define=QA_TEST_EMAIL="$EMAIL"
  --dart-define=QA_TEST_PASSWORD="$PASSWORD"
  --dart-define=QA_SKIP_TUTORIAL=1
  --dart-define=QA_SKIP_DAILY_REWARD=1
)

echo "==> Device: ${DEVICE_ID}"
flutter devices | grep -F "${DEVICE_ID}" || {
  echo "ERROR: device ${DEVICE_ID} not found. Set DEVICE_ID or connect device."
  exit 1
}

if pgrep -f "flutter run.*${DEVICE_ID}" >/dev/null 2>&1; then
  echo "WARN: flutter run active on ${DEVICE_ID} — quit with 'q' first (blocks integration VM service)"
fi

WIRELESS=0
if flutter devices 2>/dev/null | grep -F "${DEVICE_ID}" | grep -qi wireless; then
  WIRELESS=1
  echo "WARN: wireless iOS — allow Local Network on device; USB faster"
fi

DB_VERDICT="SKIP"
if [[ "$RUN_DB" == "1" ]]; then
  echo "==> Step 1: DB player journey (qa_player_journey_f2p)"
  set +e
  ./scripts/run_player_journey_smoke.sh
  DB_EXIT=$?
  set -e
  if [[ "$DB_EXIT" == "0" ]] && [[ -f "${ROOT}/reports/player_journey_smoke.json" ]]; then
    DB_VERDICT=$(python3 -c "import json; print(json.load(open('${ROOT}/reports/player_journey_smoke.json'))['verdict'])")
  else
    DB_VERDICT="FAIL"
    echo "WARN: DB journey smoke failed or skipped — continuing with device UI"
  fi
fi

DRIVE_ARGS=(
  --driver=test_driver/integration_test_driver.dart
  --target=integration_test/journeys/full_journey_smoke_test.dart
  -d "${DEVICE_ID}"
)
if [[ "$WIRELESS" == "1" ]]; then
  DRIVE_ARGS+=(--publish-port)
fi
DRIVE_ARGS+=("${DEFINE_ARGS[@]}")
DRIVE_ARGS+=(--timeout 480)

echo "==> Step 2: Gameplay journey integration (~8 min)"
# flutter drive — wireless iOS needs publish-port (auto-enabled in drive)
set +e
flutter drive "${DRIVE_ARGS[@]}" 2>&1 | tee "${LOG}"
UI_EXIT=${PIPESTATUS[0]}
set -e

python3 - <<'PY' "${LOG}" "${OUT}"
import json, re, sys
log_path, out_path = sys.argv[1], sys.argv[2]
raw = open(log_path, encoding='utf-8', errors='replace').read()
m = re.search(r'FULL_JOURNEY_SMOKE_JSON:(\{.*\})', raw, re.S)
if not m:
    sys.exit(0)
payload = m.group(1)
# Trim after last balanced brace
depth = 0
end = 0
for i, ch in enumerate(payload):
    if ch == '{':
        depth += 1
    elif ch == '}':
        depth -= 1
        if depth == 0:
            end = i + 1
            break
if end:
    payload = payload[:end]
open(out_path, 'w', encoding='utf-8').write(payload)
PY

if [[ ! -s "${OUT}" ]]; then
  echo "ERROR: no FULL_JOURNEY_SMOKE_JSON in log — integration failed early"
  exit "${UI_EXIT:-1}"
fi

python3 - <<'PY' "${OUT}" "${DB_VERDICT}" "${LOG}"
import json, sys
out_path, db_verdict, log_path = sys.argv[1:4]
report = json.load(open(out_path, encoding='utf-8'))
report['db_journey_verdict'] = db_verdict
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(report, f, ensure_ascii=False, indent=2)

verdict = report.get('verdict', 'FAIL')
print('=== Full Journey Device Smoke ===')
print(f"UI verdict: {verdict}")
print(f"DB verdict: {db_verdict}")
print(f"Steps: {report.get('pass')}/{report.get('total')}")
if report.get('failures'):
    print('-- Failures --')
    for line in report['failures'][:20]:
        print(f"  {line}")
    if len(report['failures']) > 20:
        print(f"  ... +{len(report['failures']) - 20} more")

combined = verdict == 'PASS' and db_verdict in ('PASS', 'SKIP')
sys.exit(0 if combined else 1)
PY

echo "==> Report: ${OUT}"
