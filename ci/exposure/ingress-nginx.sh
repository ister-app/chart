#!/usr/bin/env bash
# Installs ingress-nginx on the kind cluster with the project's own kind manifest: the
# controller lands on the node labelled ingress-ready=true (ci/kind-config.yaml) and binds
# hostPorts 80/443 there, which kind publishes on 127.0.0.1:8090/8443.
set -euo pipefail
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=300s

# A Ready controller pod is not yet a reachable admission webhook: the ClusterIP of
# ingress-nginx-controller-admission has no backend until the EndpointSlice is programmed,
# and until then the API server gets "connection refused" and rejects every Ingress, because
# the webhook is failurePolicy: Fail. A helm install started right after the pod-wait above
# lost that race in CI, so probe the webhook itself — a server-side dry run goes through it
# (the webhook declares sideEffects: None) without creating anything.
for _ in $(seq 60); do
  if kubectl create ingress webhook-probe -n ingress-nginx --class=nginx \
      --rule='webhook-probe.invalid/*=webhook-probe:80' --dry-run=server -o name >/dev/null 2>&1; then
    exit 0
  fi
  sleep 2
done
echo "the ingress-nginx admission webhook never became reachable; last attempt:" >&2
kubectl create ingress webhook-probe -n ingress-nginx --class=nginx \
  --rule='webhook-probe.invalid/*=webhook-probe:80' --dry-run=server -o name
exit 1
