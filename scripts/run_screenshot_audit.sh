#!/usr/bin/env bash
# Automated page-by-page screenshot capture for Code & Design Audit.
# Uses integration_test + optional flutter drive for iOS/Android device pull.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env.qa.local ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.qa.local && set +a
fi

EMAIL="${QA_TEST_EMAIL:-}"
PASSWORD="${QA_TEST_PASSWORD:-}"

if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
  echo "ERROR: QA_TEST_EMAIL and QA_TEST_PASSWORD required (.env.qa.local or env)."
  exit 1
fi

DATE_TAG="$(date +%Y-%m-%d)"
OUTPUT_DIR="${AUDIT_SCREENSHOT_DIR:-$ROOT/reports/screenshots/audit_${DATE_TAG}}"
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT_DIR")" && pwd)/$(basename "$OUTPUT_DIR")"
DEVICE="${FLUTTER_DEVICE:-176302EF-495E-4A8E-B936-2DC1537C067C}"
TIMEOUT="${SCREENSHOT_TEST_TIMEOUT:-15m}"

mkdir -p "$OUTPUT_DIR"

DEFINE_ARGS=(
  --dart-define=QA_TEST_EMAIL="$EMAIL"
  --dart-define=QA_TEST_PASSWORD="$PASSWORD"
  --dart-define=AUDIT_SCREENSHOT_DIR="$OUTPUT_DIR"
  --dart-define=QA_SKIP_DAILY_REWARD=1
  --dart-define=QA_FORCE_CHARACTER_SELECT=1
)

if [[ -n "${AUDIT_ROUTES:-}" ]]; then
  DEFINE_ARGS+=(--dart-define=AUDIT_ROUTES="$AUDIT_ROUTES")
fi

export AUDIT_SCREENSHOT_DIR="$OUTPUT_DIR"
export FLUTTER_DEVICE="$DEVICE"
TEST_EXIT=0

echo "==> Screenshot audit"
echo "    Device:  $DEVICE"
echo "    Output:  $OUTPUT_DIR"
echo "    Timeout: $TIMEOUT"

run_flutter_test() {
  flutter test integration_test/smoke/screenshot_audit_test.dart \
    "${DEFINE_ARGS[@]}" \
    -d "$DEVICE" \
    --reporter expanded \
    --timeout "$TIMEOUT"
}

run_flutter_drive() {
  flutter drive \
    --driver=test_driver/screenshot_audit_driver.dart \
    --target=integration_test/smoke/screenshot_audit_test.dart \
    "${DEFINE_ARGS[@]}" \
    -d "$DEVICE" \
    --timeout "$TIMEOUT"
}

case "$DEVICE" in
  macos|chrome)
    echo "==> Running integration test (host writes screenshots directly)"
    run_flutter_test || TEST_EXIT=$?
    ;;
  *)
    echo "==> Running flutter drive (driver pulls screenshots from device)"
    run_flutter_drive || TEST_EXIT=$?
    ;;
esac

python3 "$ROOT/scripts/generate_screenshot_manifest.py" "$OUTPUT_DIR" "$DEVICE"

if [[ -f "$OUTPUT_DIR/manifest.json" ]]; then
  CAPTURED="$(python3 -c "import json; print(json.load(open('$OUTPUT_DIR/manifest.json'))['captured'])" 2>/dev/null || echo "?")"
  echo "==> Done: $CAPTURED screenshots in $OUTPUT_DIR"
  echo "    Manifest: $OUTPUT_DIR/manifest.json"
  exit "${TEST_EXIT:-0}"
else
  echo "ERROR: manifest.json not found after run"
  exit 1
fi
