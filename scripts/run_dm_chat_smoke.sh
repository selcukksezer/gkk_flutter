#!/usr/bin/env bash
# Live DM chat smoke — conversation hide + unread + security.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env.qa.local ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.qa.local && set +a
fi

SUPABASE_URL="${SUPABASE_URL:-https://znvsyzstmxhqvdkkmgdt.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudnN5enN0bXhocXZka2ttZ2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0MzIyODUsImV4cCI6MjA4MzAwODI4NX0.uXjfsk_VnhQ8Ri9Fwg_tY_pUf1xuF5G-dgRSRRAJV5I}"

PRIMARY_EMAIL="${QA_TEST_EMAIL:-}"
PRIMARY_PASS="${QA_TEST_PASSWORD:-}"
SECONDARY_EMAIL="${QA_TEST_EMAIL_SECONDARY:-}"
SECONDARY_PASS="${QA_TEST_PASSWORD_SECONDARY:-}"
P0_EMAIL="${QA_TEST_EMAIL_P0:-}"
P0_PASS="${QA_TEST_PASSWORD_P0:-}"

if [[ -z "$PRIMARY_EMAIL" || -z "$PRIMARY_PASS" || -z "$SECONDARY_EMAIL" || -z "$SECONDARY_PASS" ]]; then
  echo "FAIL: set QA creds in .env.qa.local"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq required"
  exit 1
fi

auth_token() {
  local email=$1 pass=$2
  local res
  res=$(curl -sS "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$pass\"}")
  local token
  token=$(echo "$res" | jq -r '.access_token // empty')
  if [[ -z "$token" ]]; then
    echo "FAIL: auth $email — $(echo "$res" | jq -c '.')"
    exit 1
  fi
  printf '%s' "$token"
}

rpc() {
  local token=$1 fn=$2 payload=$3
  curl -sS "$SUPABASE_URL/rest/v1/rpc/$fn" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$payload"
}

conv_has_peer() {
  local token=$1 peer_id=$2
  rpc "$token" get_dm_conversations '{}' \
    | jq -r --arg pid "$peer_id" '[.[] | select(.peer_user_id==$pid)] | length'
}

echo "==> Auth QA users"
PRIMARY_TOKEN=$(auth_token "$PRIMARY_EMAIL" "$PRIMARY_PASS")
SECONDARY_TOKEN=$(auth_token "$SECONDARY_EMAIL" "$SECONDARY_PASS")
P0_TOKEN=""
if [[ -n "$P0_EMAIL" && -n "$P0_PASS" ]]; then
  P0_TOKEN=$(auth_token "$P0_EMAIL" "$P0_PASS")
fi

echo "==> Resolve user ids"
PRIMARY_ID=$(rpc "$SECONDARY_TOKEN" search_chat_users '{"p_query":"qa_smoke_primary","p_limit":5}' \
  | jq -r '.[] | select(.username=="qa_smoke_primary") | .id' | head -n1)
SECONDARY_ID=$(rpc "$PRIMARY_TOKEN" search_chat_users '{"p_query":"qa_smoke_secondary","p_limit":5}' \
  | jq -r '.[] | select(.username=="qa_smoke_secondary") | .id' | head -n1)

if [[ -z "$PRIMARY_ID" || -z "$SECONDARY_ID" ]]; then
  echo "FAIL: could not resolve QA user ids (primary=$PRIMARY_ID secondary=$SECONDARY_ID)"
  exit 1
fi

STAMP=$(date +%s)
MSG="smoke-conv-$STAMP"

echo "==> Secondary sends DM to primary"
SEND_RES=$(rpc "$SECONDARY_TOKEN" send_chat_message \
  "{\"p_channel\":\"dm\",\"p_content\":\"$MSG\",\"p_recipient_user_id\":\"$PRIMARY_ID\"}")
SEND_OK=$(echo "$SEND_RES" | jq -r '.success // empty')
if [[ "$SEND_OK" != "true" ]]; then
  echo "FAIL: send_chat_message — $(echo "$SEND_RES" | jq -c '.')"
  exit 1
fi

echo "==> Primary sees conversation + unread"
UNREAD_BEFORE=$(rpc "$PRIMARY_TOKEN" get_dm_conversations '{}' \
  | jq -r --arg sid "$SECONDARY_ID" '.[] | select(.peer_user_id==$sid) | .unread_count // 0' | head -n1)
UNREAD_BEFORE=${UNREAD_BEFORE:-0}
if [[ "$UNREAD_BEFORE" -lt 1 ]]; then
  echo "FAIL: expected unread >= 1, got $UNREAD_BEFORE"
  exit 1
fi

echo "==> Outsider hide does not affect primary list"
if [[ -n "$P0_TOKEN" ]]; then
  BEFORE_PRIMARY=$(conv_has_peer "$PRIMARY_TOKEN" "$SECONDARY_ID")
  rpc "$P0_TOKEN" hide_dm_conversation "{\"p_peer_user_id\":\"$SECONDARY_ID\"}" >/dev/null
  AFTER_PRIMARY=$(conv_has_peer "$PRIMARY_TOKEN" "$SECONDARY_ID")
  if [[ "$AFTER_PRIMARY" != "$BEFORE_PRIMARY" ]]; then
    echo "FAIL: outsider hide changed primary conversation list"
    exit 1
  fi
else
  echo "WARN: skip outsider test (no P0 creds)"
fi

echo "==> Primary hides conversation from list"
HIDE_RES=$(rpc "$PRIMARY_TOKEN" hide_dm_conversation "{\"p_peer_user_id\":\"$SECONDARY_ID\"}")
HIDE_OK=$(echo "$HIDE_RES" | jq -r '.success // empty')
if [[ "$HIDE_OK" != "true" ]]; then
  echo "FAIL: hide_dm_conversation — $(echo "$HIDE_RES" | jq -c '.')"
  exit 1
fi

echo "==> Conversation removed from primary list"
PRIMARY_LIST=$(conv_has_peer "$PRIMARY_TOKEN" "$SECONDARY_ID")
if [[ "$PRIMARY_LIST" != "0" ]]; then
  echo "FAIL: conversation still in primary list (count=$PRIMARY_LIST)"
  exit 1
fi

echo "==> Secondary still has conversation with primary"
SECONDARY_LIST=$(conv_has_peer "$SECONDARY_TOKEN" "$PRIMARY_ID")
if [[ "$SECONDARY_LIST" -lt 1 ]]; then
  echo "FAIL: secondary lost conversation"
  exit 1
fi

echo "==> New message restores conversation for primary"
sleep 3
RESTORE_MSG="smoke-restore-$STAMP"
SEND2=$(rpc "$SECONDARY_TOKEN" send_chat_message \
  "{\"p_channel\":\"dm\",\"p_content\":\"$RESTORE_MSG\",\"p_recipient_user_id\":\"$PRIMARY_ID\"}")
if [[ "$(echo "$SEND2" | jq -r '.success // empty')" != "true" ]]; then
  echo "FAIL: restore send — $(echo "$SEND2" | jq -c '.')"
  exit 1
fi
PRIMARY_LIST2=$(conv_has_peer "$PRIMARY_TOKEN" "$SECONDARY_ID")
if [[ "$PRIMARY_LIST2" -lt 1 ]]; then
  echo "FAIL: conversation did not reappear after new message"
  exit 1
fi

echo "PASS: DM conversation smoke ($MSG)"
echo "  hide list OK, secondary retained OK, restore on new message OK"
