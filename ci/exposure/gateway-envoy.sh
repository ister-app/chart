#!/usr/bin/env bash
# Installs Envoy Gateway and a Gateway in the release namespace for ci/values-gateway-envoy.yaml
# (listener "http" on port 80, hostname ister.test). kind has no LoadBalancer, so the e2e
# reaches the Envoy Service with a port-forward: ci/exposure/gateway-envoy-forward.sh.
set -euo pipefail
NAMESPACE="${NAMESPACE:-ister}"
EG_VERSION="${EG_VERSION:-1.9.1}"

helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version "$EG_VERSION" \
  -n envoy-gateway-system --create-namespace --wait --timeout 5m
kubectl wait -n envoy-gateway-system --for=condition=Available deploy/envoy-gateway --timeout=300s

kubectl apply -f - <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ister-gateway
  namespace: $NAMESPACE
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: ister.test
      allowedRoutes:
        namespaces:
          from: Same
YAML
kubectl wait -n "$NAMESPACE" --for=condition=Programmed gateway/ister-gateway --timeout=300s
