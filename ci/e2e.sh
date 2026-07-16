#!/usr/bin/env bash
#
# End-to-end test: does a fresh install actually serve media?
#
# Mints a JWT at the mock issuer and runs the scenario scripts in ci/e2e/ in order:
# scanning every library type, podcast subscribe/refresh, HLS streaming with a real
# transcode, epub resources + reading progress, search and watch status. Everything
# goes through the same path a real client uses, so it also covers the chart's
# OIDC_URL wiring and the auth layer — not just the scanner.
#
# Usage: ci/e2e.sh [release] [namespace]
#   E2E_ONLY=<pattern>  — run only scenario files matching the glob (e.g. E2E_ONLY=30-*)
#   E2E_SKIP=<pattern>  — skip scenario files matching the glob

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

export RELEASE="${1:-ister}"
export NAMESPACE="${2:-ister}"
export SERVER_PORT=18080
export OIDC_PORT=18081
export API="http://localhost:${SERVER_PORT}/api"

PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

source "$SCRIPT_DIR/e2e/lib.sh"

echo "==> Port-forwarding"
forward "${RELEASE}-server" 8080 "$SERVER_PORT"
forward mock-oidc 8080 "$OIDC_PORT"
wait_for "http://localhost:${SERVER_PORT}/api/.well-known/ister" \
  || fail "server not reachable on :${SERVER_PORT}"
wait_for "http://localhost:${OIDC_PORT}/default/.well-known/openid-configuration" \
  || fail "mock issuer not reachable on :${OIDC_PORT}"

echo "==> Minting a token with roles=[user]"
mint_token
export TOKEN

echo "==> Checking the token is actually accepted (authenticated query)"
# If OIDC_URL, the issuer or the roles claim were wrong, this is where it shows up —
# with a clear error, rather than as a mysteriously empty library later on.
libraries=$(gql '{ libraries { id name type } }')
echo "$libraries" | jq -e '.errors' >/dev/null 2>&1 \
  && fail "authenticated query rejected: $(echo "$libraries" | jq -c '.errors')"
echo "$libraries" | jq -e '.data.libraries | length >= 2' >/dev/null \
  || fail "expected the configured libraries, got: $(echo "$libraries" | jq -c '.data.libraries')"

for scenario in "$SCRIPT_DIR"/e2e/[0-9]*.sh; do
  name=$(basename "$scenario")
  if [ -n "${E2E_ONLY:-}" ] && [[ "$name" != ${E2E_ONLY} ]]; then
    echo "==> Skipping $name (E2E_ONLY=${E2E_ONLY})"
    continue
  fi
  if [ -n "${E2E_SKIP:-}" ] && [[ "$name" == ${E2E_SKIP} ]]; then
    echo "==> Skipping $name (E2E_SKIP=${E2E_SKIP})"
    continue
  fi
  echo "==> Scenario $name"
  # Scenarios run in this shell so they share TOKEN, API and the helpers.
  source "$scenario"
done

echo "==> PASS: all scenarios completed"
