#!/usr/bin/env bash
# Tier-2 integration: programmatic player journey (no manual taps).
# Requires QA bot creds in .env.qa.local or env vars.
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
  echo "ERROR: QA_TEST_EMAIL and QA_TEST_PASSWORD required."
  echo "  Create .env.qa.local or export vars."
  echo "  Optional: QA_INTEGRATION_ENABLED=1 in run_nightly_qa.sh"
  exit 1
fi

echo "==> Auto player integration smoke"
echo "    Test: integration_test/journeys/auto_player_smoke_test.dart"
echo "    Flow: login → home → character (rep) → dungeon → reputation → home"
echo ""
echo "    Optional Tier 3: patrol dev_dependency for native dialog handling — not required for H1."

flutter test integration_test/journeys/auto_player_smoke_test.dart \
  --dart-define=QA_TEST_EMAIL="$EMAIL" \
  --dart-define=QA_TEST_PASSWORD="$PASSWORD" \
  --reporter expanded \
  --timeout 4m

echo "==> Done"
