#!/usr/bin/env bash
# Export top QA accounts from Supabase for multi-account action audit.
# Passwords are NOT stored in DB — uses known QA password pattern from create script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LIMIT="${1:-20}"
OUT_ENV="${ROOT}/.env.qa.accounts"
OUT_JSON="${ROOT}/reports/qa_accounts_bootstrap.json"

# Known passwords (scripts/create_qa_integration_accounts.sh)
PRIMARY_PASS="${QA_TEST_PASSWORD:-GkkQaSmoke2026!Primary}"
P0_PASS="${QA_TEST_PASSWORD_P0:-GkkQaSmoke2026!P0Flows}"
BOT_PASS="${QA_BOT_PASSWORD:-GkkQaBot2026!Sim}"

mkdir -p "${ROOT}/reports"

echo "==> Bootstrap QA accounts (limit=${LIMIT})"

SQL="
SELECT email, id::text AS auth_id
FROM auth.users
WHERE email ILIKE '%qa%'
   OR email ILIKE '%test%'
   OR email ILIKE '%smoke%'
   OR email ILIKE '%bot%'
ORDER BY
  CASE
    WHEN email LIKE 'qa_smoke_%@gkk.test' THEN 0
    WHEN email LIKE 'qa_bot_%@sim.local' THEN 1
    ELSE 2
  END,
  email
LIMIT ${LIMIT};
"

RAW=""
if command -v supabase >/dev/null 2>&1; then
  supabase db query --linked "$SQL" -o json > "${OUT_JSON}.raw" 2>/dev/null || true
  RAW="$(cat "${OUT_JSON}.raw" 2>/dev/null || true)"
fi

if [[ -z "$RAW" ]] && [[ -n "${DATABASE_URL:-}" ]] && command -v psql >/dev/null 2>&1; then
  psql "${DATABASE_URL}" -At -F'|' -c "$SQL" > "${OUT_JSON}.raw"
  RAW="$(cat "${OUT_JSON}.raw")"
fi

if [[ ! -s "${OUT_JSON}.raw" ]]; then
  echo "WARN: DB query failed — falling back to create_qa_integration_accounts.sh defaults"
  cat > "${OUT_ENV}" <<EOF
# Fallback QA accounts — DO NOT COMMIT
QA_TEST_EMAIL=qa_smoke_primary@gkk.test
QA_TEST_PASSWORD=${PRIMARY_PASS}
QA_TEST_EMAIL_SECONDARY=qa_smoke_secondary@gkk.test
QA_TEST_PASSWORD_SECONDARY=${PRIMARY_PASS}
QA_ACCOUNTS=qa_smoke_primary@gkk.test:${PRIMARY_PASS},qa_smoke_secondary@gkk.test:${PRIMARY_PASS},qa_smoke_p0@gkk.test:${P0_PASS:-GkkQaSmoke2026!P0Flows}
EOF
  echo "==> Wrote fallback ${OUT_ENV}"
  exit 0
fi

python3 - <<'PY' "${OUT_JSON}.raw" "${OUT_JSON}" "${OUT_ENV}" "${PRIMARY_PASS}" "${BOT_PASS}"
import json, re, sys
raw_path, out_json, out_env, primary_pass, bot_pass = sys.argv[1:6]
raw = open(raw_path, encoding='utf-8').read().strip()
rows = []
if '"rows"' in raw:
    try:
        wrapper = json.loads(raw[raw.find('{'):raw.rfind('}')+1])
        rows = wrapper.get('rows') or []
    except json.JSONDecodeError:
        pass
if not rows:
    for line in raw.splitlines():
        if '|' in line:
            email, auth_id = line.split('|', 1)
            rows.append({'email': email.strip(), 'auth_id': auth_id.strip()})

pairs = []
for row in rows:
    email = row.get('email') or row.get('Email')
    if not email:
        continue
    pwd = bot_pass if '@sim.local' in email else primary_pass
    pairs.append((email, pwd))

with open(out_json, 'w', encoding='utf-8') as f:
    json.dump({'count': len(pairs), 'accounts': [{'email': e, 'auth_id': r.get('auth_id')} for e, r in zip([p[0] for p in pairs], rows)]}, f, indent=2)

qa_accounts = ','.join(f'{e}:{p}' for e, p in pairs)
lines = [
    '# QA accounts from DB bootstrap — DO NOT COMMIT',
    f'QA_ACCOUNTS={qa_accounts}',
    f'QA_TEST_EMAIL={pairs[0][0] if pairs else "qa_smoke_primary@gkk.test"}',
    f'QA_TEST_PASSWORD={pairs[0][1] if pairs else primary_pass}',
]
if len(pairs) > 1:
    lines.append(f'QA_TEST_EMAIL_SECONDARY={pairs[1][0]}')
    lines.append(f'QA_TEST_PASSWORD_SECONDARY={pairs[1][1]}')
open(out_env, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print(f'Exported {len(pairs)} QA accounts -> {out_env}')
PY

echo "==> Accounts JSON: ${OUT_JSON}"
echo "==> Env file: ${OUT_ENV}"
echo "    Password pattern: @gkk.test -> PRIMARY, @sim.local -> BOT (not stored in DB)"
