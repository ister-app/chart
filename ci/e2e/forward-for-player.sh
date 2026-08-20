#!/usr/bin/env bash
#
# Host access for the player integration tests:
#   localhost:8080  → the server (matches the advertised default server.url
#                     http://localhost:8080/api in /.well-known/ister)
#   localhost:18081 → the mock OIDC issuer (the test harness mints its JWTs here)
#
# A cluster created from ci/kind-config.yaml already publishes both through the
# node's NodePorts, in which case this script only waits: a published port keeps
# working under the HLS load the player tests generate, while a `kubectl
# port-forward` tunnel starts timing out requests halfway through the suite
# (the player then hangs on a GraphQL call and never starts playback).
#
# Older clusters without those port mappings fall back to port-forwarding.
#
# Keeps running until interrupted. Usage: ci/e2e/forward-for-player.sh [release] [namespace]

set -euo pipefail

RELEASE="${1:-ister}"
NAMESPACE="${2:-ister}"

published() {
  curl -fsS -o /dev/null --max-time 5 http://localhost:8080/api/.well-known/ister 2>/dev/null
}

for _ in $(seq 1 30); do
  published && break
  sleep 1
done

if published; then
  echo "Server already published on :8080 (NodePort); no port-forward needed"
  # The caller runs this in the background and kills it at the end of the job.
  while true; do sleep 3600; done
fi

cleanup() { kill 0; }
trap cleanup EXIT

kubectl port-forward -n "$NAMESPACE" "svc/${RELEASE}-server" 8080:8080 &
kubectl port-forward -n "$NAMESPACE" svc/mock-oidc 18081:8080 &

echo "Forwarding ${RELEASE}-server on :8080 and mock-oidc on :18081 (Ctrl-C to stop)"
wait
