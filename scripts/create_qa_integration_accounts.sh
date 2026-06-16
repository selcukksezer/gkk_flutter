#!/usr/bin/env bash
# Create real Supabase Auth QA accounts for integration smoke tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SUPABASE_URL="${SUPABASE_URL:-https://znvsyzstmxhqvdkkmgdt.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudnN5enN0bXhocXZka2ttZ2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0MzIyODUsImV4cCI6MjA4MzAwODI4NX0.uXjfsk_VnhQ8Ri9Fwg_tY_pUf1xuF5G-dgRSRRAJV5I}"

PRIMARY_EMAIL="${QA_TEST_EMAIL:-qa_smoke_primary@gkk.test}"
PRIMARY_PASS="${QA_TEST_PASSWORD:-GkkQaSmoke2026!Primary}"
SECONDARY_EMAIL="${QA_TEST_EMAIL_SECONDARY:-qa_smoke_secondary@gkk.test}"
SECONDARY_PASS="${QA_TEST_PASSWORD_SECONDARY:-GkkQaSmoke2026!Secondary}"
P0_EMAIL="${QA_TEST_EMAIL_P0:-qa_smoke_p0@gkk.test}"
P0_PASS="${QA_TEST_PASSWORD_P0:-GkkQaSmoke2026!P0Flows}"

signup() {
  local email="$1"
  local password="$2"
  local username="$3"
  local resp
  resp=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/signup" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\",\"data\":{\"username\":\"${username}\"}}")
  if echo "$resp" | grep -q '"access_token"'; then
    echo "  OK signup: ${email}"
  elif echo "$resp" | grep -qi 'already registered'; then
    echo "  EXISTS: ${email} (login ok)"
  else
    echo "  WARN ${email}: $(echo "$resp" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("msg",d.get("error_description",d)))' 2>/dev/null || echo "$resp")"
  fi
}

echo "==> Creating QA integration accounts (Supabase Auth signup)"
signup "$PRIMARY_EMAIL" "$PRIMARY_PASS" "qa_smoke_primary"
signup "$SECONDARY_EMAIL" "$SECONDARY_PASS" "qa_smoke_secondary"
signup "$P0_EMAIL" "$P0_PASS" "qa_smoke_p0"

cat > .env.qa.local <<EOF
# QA integration test accounts — DO NOT COMMIT (gitignored)
QA_TEST_EMAIL=${PRIMARY_EMAIL}
QA_TEST_PASSWORD=${PRIMARY_PASS}
QA_TEST_EMAIL_SECONDARY=${SECONDARY_EMAIL}
QA_TEST_PASSWORD_SECONDARY=${SECONDARY_PASS}
QA_TEST_EMAIL_P0=${P0_EMAIL}
QA_TEST_PASSWORD_P0=${P0_PASS}
EOF

echo "==> Wrote .env.qa.local"
echo "==> Run profile bootstrap SQL in Supabase (character_class, stats) if new accounts."
