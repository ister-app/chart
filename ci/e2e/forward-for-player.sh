#!/usr/bin/env bash
#
# Port-forwards for the player integration tests:
#   localhost:8080  → the server (matches the advertised default server.url
#                     http://localhost:8080/api in /.well-known/ister)
#   localhost:18081 → the mock OIDC issuer (the test harness mints its JWTs here)
#
# Keeps running until interrupted. Usage: ci/e2e/forward-for-player.sh [release] [namespace]

set -euo pipefail

RELEASE="${1:-ister}"
NAMESPACE="${2:-ister}"

cleanup() { kill 0; }
trap cleanup EXIT

kubectl port-forward -n "$NAMESPACE" "svc/${RELEASE}-server" 8080:8080 &
kubectl port-forward -n "$NAMESPACE" svc/mock-oidc 18081:8080 &

echo "Forwarding ${RELEASE}-server on :8080 and mock-oidc on :18081 (Ctrl-C to stop)"
wait
