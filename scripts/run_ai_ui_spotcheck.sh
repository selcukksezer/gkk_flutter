#!/usr/bin/env bash
# UI spot-check: 1 device, login as qa_bot_001, navigate core routes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BOT_INDEX="${AI_SPOT_BOT:-1}"
EMAIL="qa_bot_$(printf '%03d' "${BOT_INDEX}")@sim.local"
PASS="${AI_BOT_PASSWORD:-QaLivePlay300!}"
DEVICE="${AI_DEVICE:-}"

echo "==> UI spot-check bot=${BOT_INDEX} email=${EMAIL}"

ARGS=(
  --dart-define="QA_TEST_EMAIL=${EMAIL}"
  --dart-define="QA_TEST_PASSWORD=${PASS}"
  --dart-define="QA_SKIP_DAILY_REWARD=1"
  --dart-define="QA_SKIP_TUTORIAL=1"
)

if [[ -n "${DEVICE}" ]]; then
  ARGS+=(-d "${DEVICE}")
fi

flutter test integration_test/agent/ai_ui_spotcheck_test.dart "${ARGS[@]}"
