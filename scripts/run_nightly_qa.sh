#!/usr/bin/env bash
# Nightly QA orchestrator — flutter smoke + DB RPC smokes + optional integration.
# Usage: ./scripts/run_nightly_qa.sh
# Env: QA_FAIL_FAST=1 exit on first fail (default: collect all)
#      QA_INTEGRATION_ENABLED=1 + QA creds → integration_test journey
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env.qa.local ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.qa.local && set +a
  echo "==> Loaded .env.qa.local"
fi

FAIL_FAST="${QA_FAIL_FAST:-0}"
FAILURES=()
SKIPPED=()

mkdir -p "${ROOT}/reports"

run_step() {
  local name="$1"
  shift
  echo ""
  echo "========================================"
  echo "==> ${name}"
  echo "========================================"
  if "$@"; then
    echo "✓ PASS: ${name}"
    return 0
  fi
  local code=$?
  echo "✗ FAIL: ${name} (exit ${code})"
  FAILURES+=("${name}")
  if [[ "${FAIL_FAST}" == "1" ]]; then
    exit "${code}"
  fi
  return "${code}"
}

skip_step() {
  local name="$1"
  local reason="$2"
  echo ""
  echo "⊘ SKIP: ${name} — ${reason}"
  SKIPPED+=("${name}: ${reason}")
}

can_run_db_smoke() {
  if command -v supabase >/dev/null 2>&1; then
    if supabase db query --linked "SELECT 1" >/dev/null 2>&1; then
      return 0
    fi
  fi
  if [[ -n "${DATABASE_URL:-}" ]] && command -v psql >/dev/null 2>&1; then
    if psql "${DATABASE_URL}" -At -c "SELECT 1" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

echo "==> GKK Nightly QA — $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Tier 1 — always (no DB)
run_step "flutter smoke tests" flutter test test/smoke/ || true

# Tier 1b — DB RPC smokes (skip if no linked project / DATABASE_URL)
if can_run_db_smoke; then
  run_step "dungeon siege smoke" "${ROOT}/scripts/run_dungeon_siege_smoke.sh" || true
  run_step "bugfix batch smoke" "${ROOT}/scripts/run_bugfix_batch_smoke.sh" || true
  run_step "horse race fairness smoke" "${ROOT}/scripts/run_horse_race_fairness_smoke.sh" 200 || true
  run_step "reputation smoke" "${ROOT}/scripts/run_reputation_smoke.sh" || true
  run_step "player journey smoke" "${ROOT}/scripts/run_player_journey_smoke.sh" || true
else
  skip_step "DB RPC smokes" "no supabase link or DATABASE_URL — set secrets or run: supabase link"
  echo "    CI: add SUPABASE_DB_URL or DATABASE_URL secret"
  echo "    Local: supabase link && supabase db push --linked"
fi

# Tier 2 — integration (optional gate)
if [[ "${QA_INTEGRATION_ENABLED:-0}" == "1" ]]; then
  if [[ -n "${QA_TEST_EMAIL:-}" && -n "${QA_TEST_PASSWORD:-}" ]]; then
    run_step "auto player integration" "${ROOT}/scripts/run_auto_player_integration.sh" || true
  else
    skip_step "auto player integration" "QA_INTEGRATION_ENABLED=1 but QA_TEST_EMAIL/PASSWORD missing"
  fi
else
  skip_step "auto player integration" "set QA_INTEGRATION_ENABLED=1 in .env.qa.local to enable"
fi

echo ""
echo "========================================"
echo "==> Nightly QA Summary"
echo "========================================"
echo "Failures: ${#FAILURES[@]}"
for f in "${FAILURES[@]:-}"; do echo "  ✗ ${f}"; done
echo "Skipped: ${#SKIPPED[@]}"
for s in "${SKIPPED[@]:-}"; do echo "  ⊘ ${s}"; done
echo "Reports: ${ROOT}/reports/"
echo ""
echo "Optional Tier 3 (Patrol native taps): add patrol dev_dependency — not required for H1."
echo "One-command local run: ./scripts/run_nightly_qa.sh"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  exit 1
fi

echo "==> All steps passed"
exit 0
