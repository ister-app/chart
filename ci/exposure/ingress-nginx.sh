#!/usr/bin/env bash
# Installs ingress-nginx on the kind cluster with the project's own kind manifest: the
# controller lands on the node labelled ingress-ready=true (ci/kind-config.yaml) and binds
# hostPorts 80/443 there, which kind publishes on 127.0.0.1:8090/8443.
set -euo pipefail
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=300s
