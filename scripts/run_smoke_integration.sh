#!/usr/bin/env bash
# Fast smoke gate — single integration test, ~2 min with QA creds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env.qa.local ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.qa.local && set +a
fi

EMAIL="${QA_TEST_EMAIL:-}"
PASSWORD="${QA_TEST_PASSWORD:-}"

DEFINE_ARGS=()
if [[ -n "$EMAIL" && -n "$PASSWORD" ]]; then
  DEFINE_ARGS+=(--dart-define=QA_TEST_EMAIL="$EMAIL" --dart-define=QA_TEST_PASSWORD="$PASSWORD")
  echo "==> QA creds: full real integration"
else
  echo "==> No QA creds: unit tests only"
fi

echo "==> Unit smoke tests"
flutter test test/smoke/

if [[ -n "$EMAIL" && -n "$PASSWORD" ]]; then
  echo "==> Integration smoke gate (single build, 5min timeout)"
  flutter test integration_test/smoke/smoke_gate_test.dart \
    ${DEFINE_ARGS[@]+"${DEFINE_ARGS[@]}"} \
    --reporter expanded \
    --timeout 5m
fi

echo "==> Done"
