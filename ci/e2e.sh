#!/usr/bin/env bash
#
# End-to-end test: does a fresh install actually index media?
#
# Mints a JWT at the mock issuer, triggers a library scan through the real GraphQL API,
# and polls until the scanner has produced shows and movies. Everything goes through the
# same path a real client uses, so it also covers the chart's OIDC_URL wiring and the
# auth layer — not just the scanner.
#
# Usage: ci/e2e.sh [release] [namespace]

set -euo pipefail

RELEASE="${1:-ister}"
NAMESPACE="${2:-ister}"
SERVER_PORT=18080
OIDC_PORT=18081
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-240}"

API="http://localhost:${SERVER_PORT}/api"
PIDS=()

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

forward() { # svc port -> localhost port
  kubectl port-forward -n "$NAMESPACE" "svc/$1" "$3:$2" >/dev/null 2>&1 &
  PIDS+=($!)
}

wait_for() { # url
  for _ in $(seq 1 30); do
    curl -fsS -o /dev/null "$1" 2>/dev/null && return 0
    sleep 1
  done
  return 1
}

# GraphQL over HTTP. Passes the query as a JSON string via jq so quoting can't bite us.
gql() { # query [token]
  local body auth=()
  body=$(jq -n --arg q "$1" '{query: $q}')
  [ -n "${2:-}" ] && auth=(-H "Authorization: Bearer $2")
  curl -fsS -X POST "$API/graphql" \
    -H 'Content-Type: application/json' \
    "${auth[@]}" \
    -d "$body"
}

echo "==> Port-forwarding"
forward "${RELEASE}-server" 8080 "$SERVER_PORT"
forward mock-oidc 8080 "$OIDC_PORT"
wait_for "http://localhost:${SERVER_PORT}/api/.well-known/ister" \
  || fail "server not reachable on :${SERVER_PORT}"
wait_for "http://localhost:${OIDC_PORT}/default/.well-known/openid-configuration" \
  || fail "mock issuer not reachable on :${OIDC_PORT}"

echo "==> Minting a token with roles=[user]"
# The Host header matters: mock-oauth2-server builds the `iss` claim from it, and the
# server rejects any token whose `iss` differs from OIDC_URL (http://mock-oidc:8080/default).
TOKEN=$(curl -fsS -X POST "http://localhost:${OIDC_PORT}/default/token" \
  -H 'Host: mock-oidc:8080' \
  -d grant_type=client_credentials \
  -d client_id=ci \
  -d client_secret=ci-secret \
  -d scope=ister | jq -r '.access_token')
[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || fail "no access_token from the mock issuer"

echo "==> Checking the token is actually accepted (authenticated query)"
# If OIDC_URL, the issuer or the roles claim were wrong, this is where it shows up —
# with a clear error, rather than as a mysteriously empty library later on.
libraries=$(gql '{ libraries { id name type } }' "$TOKEN")
echo "$libraries" | jq -e '.errors' >/dev/null 2>&1 \
  && fail "authenticated query rejected: $(echo "$libraries" | jq -c '.errors')"
echo "$libraries" | jq -e '.data.libraries | length >= 2' >/dev/null \
  || fail "expected the 2 configured libraries, got: $(echo "$libraries" | jq -c '.data.libraries')"

echo "==> Triggering the library scan"
scan=$(gql 'mutation { scanLibrary }' "$TOKEN")
echo "$scan" | jq -e '.data.scanLibrary == true' >/dev/null \
  || fail "scanLibrary did not return true: $scan"

# The scan is asynchronous (RabbitMQ events, then ffprobe per file). Rows appear within
# seconds, but poll rather than sleep — a fixed sleep is either flaky or slow.
echo "==> Waiting for the scanner to index media (up to ${TIMEOUT_SECONDS}s)"
deadline=$((SECONDS + TIMEOUT_SECONDS))
shows=0
movies=0
while [ $SECONDS -lt $deadline ]; do
  shows=$(gql '{ shows(size: 1) { totalElements } }' "$TOKEN" | jq -r '.data.shows.totalElements // 0')
  movies=$(gql '{ movies(size: 1) { totalElements } }' "$TOKEN" | jq -r '.data.movies.totalElements // 0')
  echo "    shows=$shows movies=$movies"
  if [ "$shows" -gt 0 ] && [ "$movies" -gt 0 ]; then
    echo "==> PASS: indexed $shows show(s) and $movies movie(s)"
    exit 0
  fi
  sleep 5
done

fail "nothing indexed within ${TIMEOUT_SECONDS}s (shows=$shows movies=$movies)"
