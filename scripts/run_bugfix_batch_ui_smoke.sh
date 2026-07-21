#!/usr/bin/env bash
# UI integration smoke for bugfix batch (needs device + QA credentials)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EMAIL="${QA_TEST_EMAIL:-}"
PASS="${QA_TEST_PASSWORD:-}"

if [[ -z "$EMAIL" || -z "$PASS" ]]; then
  echo "Set QA_TEST_EMAIL and QA_TEST_PASSWORD"
  exit 1
fi

echo "==> Bugfix batch UI smoke (integration_test)"
flutter test integration_test/smoke/bugfix_batch_ui_test.dart \
  --dart-define=QA_TEST_EMAIL="$EMAIL" \
  --dart-define=QA_TEST_PASSWORD="$PASS"

echo "==> Debug log: ${ROOT}/.cursor/debug-02eb2a.log"
