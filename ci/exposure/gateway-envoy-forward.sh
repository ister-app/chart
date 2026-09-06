#!/usr/bin/env bash
# Port-forwards the Envoy Service of the Gateway from ci/exposure/gateway-envoy.sh to
# localhost:8091 (kind has no LoadBalancer). A tunnel is fine for the gateway smoke: it
# runs the streaming scenario only, not the whole suite that overwhelms a forward.
# Keeps running until interrupted. Usage: ci/exposure/gateway-envoy-forward.sh [namespace]
set -euo pipefail
NAMESPACE="${1:-ister}"
svc=$(kubectl get svc -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-namespace="$NAMESPACE",gateway.envoyproxy.io/owning-gateway-name=ister-gateway \
  -o jsonpath='{.items[0].metadata.name}')
[ -n "$svc" ] || { echo "no Envoy Service for gateway ister-gateway" >&2; exit 1; }
exec kubectl port-forward -n envoy-gateway-system "svc/$svc" 8091:80
