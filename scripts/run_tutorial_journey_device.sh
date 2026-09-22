#!/usr/bin/env bash
# Tutorial LIVE journey smoke on physical device / simulator.
# Captures per-step screenshots + FIXES.md.
# CRITICAL: do NOT set QA_SKIP_TUTORIAL (tutorial must run).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEVICE_ID="${DEVICE_ID:-176302EF-495E-4A8E-B936-2DC1537C067C}"
DATE_TAG="$(date +%Y-%m-%d_%H%M%S)"
SHOT_DIR="${ROOT}/reports/screenshots/tutorial_${DATE_TAG}"
OUT="${ROOT}/reports/tutorial_journey_device.json"
FIXES="${SHOT_DIR}/FIXES.md"
LOG="${ROOT}/reports/tutorial_journey_device.log"

mkdir -p "${ROOT}/reports" "${SHOT_DIR}"

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
  if [[ -n "${QA_ACCOUNTS:-}" ]]; then
    FIRST="${QA_ACCOUNTS%%,*}"
    EMAIL="${FIRST%%:*}"
    PASSWORD="${FIRST#*:}"
  fi
fi

if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
  echo "ERROR: QA_TEST_EMAIL / QA_TEST_PASSWORD required (.env.qa.local or .env.qa.accounts)"
  exit 1
fi

export AUDIT_SCREENSHOT_DIR="${SHOT_DIR}"

DEFINE_ARGS=(
  --dart-define=QA_TEST_EMAIL="$EMAIL"
  --dart-define=QA_TEST_PASSWORD="$PASSWORD"
  --dart-define=QA_SKIP_DAILY_REWARD=1
  --dart-define=QA_SKIP_COMEBACK_SUMMARY=1
  --dart-define=QA_ALLOW_MOCK_ADS=1
  --dart-define=AUDIT_SCREENSHOT_DIR="$SHOT_DIR"
)

echo "==> Device: ${DEVICE_ID}"
echo "==> Screenshots: ${SHOT_DIR}"
flutter devices | grep -F "${DEVICE_ID}" || {
  echo "ERROR: device ${DEVICE_ID} not found. Set DEVICE_ID or connect device."
  exit 1
}

if pgrep -f "flutter run.*${DEVICE_ID}" >/dev/null 2>&1; then
  echo "WARN: flutter run active on ${DEVICE_ID} — quit with 'q' first"
fi

WIRELESS=0
# Do not let pipefail abort when device is not wireless (grep exit 1).
if flutter devices 2>/dev/null | grep -F "${DEVICE_ID}" | grep -qi wireless >/dev/null 2>&1; then
  WIRELESS=1
  echo "WARN: wireless iOS — USB faster"
fi

echo "==> Unit tutorial suite (preflight)"
if [[ "${SKIP_UNIT:-0}" == "1" ]]; then
  echo "SKIP_UNIT=1 — skipping unit preflight"
else
  set +e
  flutter test test/core/tutorial/ --reporter compact
  UNIT_EXIT=$?
  set -e
  if [[ "$UNIT_EXIT" != "0" ]]; then
    echo "ERROR: tutorial unit tests failed — aborting device drive"
    exit "$UNIT_EXIT"
  fi
fi

# Use screenshot driver so takeScreenshot bytes land on host disk.
DRIVE_ARGS=(
  --driver=test_driver/screenshot_audit_driver.dart
  --target=integration_test/tutorial/tutorial_live_journey_smoke_test.dart
  -d "${DEVICE_ID}"
)
if [[ "$WIRELESS" == "1" ]]; then
  DRIVE_ARGS+=(--publish-port)
fi
DRIVE_ARGS+=("${DEFINE_ARGS[@]}")
DRIVE_ARGS+=(--timeout 900)

echo "==> flutter drive tutorial live journey (screenshots ON)"
set +e
flutter drive "${DRIVE_ARGS[@]}" 2>&1 | tee "${LOG}"
DRIVE_EXIT=${PIPESTATUS[0]}
set -e

python3 - <<PY
import json, re
from pathlib import Path

log = Path("${LOG}").read_text(errors="replace")
out = Path("${OUT}")
fixes = Path("${FIXES}")
shot = Path("${SHOT_DIR}")
shot.mkdir(parents=True, exist_ok=True)

steps = []
for m in re.finditer(r"TUTORIAL_STEP_JSON:(\{.*\})", log):
    try:
        steps.append(json.loads(m.group(1)))
    except Exception:
        pass

failures = [f"{s['id']}: {s.get('error')}" for s in steps if not s.get('pass')]
data = {
    "run_id": None,
    "test_name": "tutorial_live_journey_smoke",
    "screenshot_dir": str(shot),
    "verdict": "PASS" if steps and not failures else "FAIL",
    "pass": sum(1 for s in steps if s.get("pass")),
    "total": len(steps),
    "failures": failures,
    "steps": steps,
    "drive_exit": ${DRIVE_EXIT},
}
# Prefer full blob if parseable
m = re.search(r"TUTORIAL_JOURNEY_SMOKE_JSON:(\{.*\})", log)
if m:
    try:
        full = json.loads(m.group(1))
        full["drive_exit"] = ${DRIVE_EXIT}
        full["screenshot_dir"] = str(shot)
        data = full
    except Exception:
        pass

out.write_text(json.dumps(data, indent=2) + "\n")
(shot / "report.json").write_text(json.dumps(data, indent=2) + "\n")

lines = [
    "# Tutorial LIVE Smoke — Düzeltme Notları",
    "",
    f"- verdict: **{data.get('verdict')}**",
    f"- pass: {data.get('pass')}/{data.get('total')}",
    f"- screenshot_dir: `{shot}`",
    "",
]
for s in data.get("steps", []):
    lines += [
        f"## {s.get('id')}",
        "",
        f"- pass: {s.get('pass')}",
        f"- after: `{s.get('screenshot_after')}`",
    ]
    if s.get("error"):
        lines.append(f"- error: `{s.get('error')}`")
    lines.append("- fix_notes:")
    for n in s.get("fix_notes") or []:
        lines.append(f"  - {n}")
    lines.append("")
fixes.write_text("\n".join(lines) + "\n")

pngs = list(shot.glob("*.png"))
print(f"Wrote {out}")
print(f"Wrote {fixes}")
print(f"PNGs in shot dir: {len(pngs)}")
print("Final verdict:", data.get("verdict"), "exit:", ${DRIVE_EXIT})
PY

exit "${DRIVE_EXIT}"
