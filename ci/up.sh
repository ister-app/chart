#!/usr/bin/env bash
#
# Brings up a complete test environment: media fixtures, a kind cluster with the
# testdata mounted, the mock OIDC issuer, the podcast feed server and the chart itself.
# Idempotent: generators skip existing files, the cluster is reused when it exists and
# helm upgrades in place. Used by `make up` locally and by the player repo's
# integration-e2e workflow; the chart repo's own CI does the same steps inline.
#
# Usage: ci/up.sh
#   TESTDATA_DIR   — the testdata checkout (default: ../testdata next to this chart)
#   CLUSTER_NAME   — kind cluster name (default: ister)
#   NAMESPACE      — namespace to install into (default: ister)
#   RELEASE        — helm release name (default: ister)
#
# Image pinning (all optional; by default the chart's own pinned version deploys):
#   SERVER_IMAGE_REPOSITORY / SERVER_IMAGE_TAG / SERVER_IMAGE_PULL_POLICY
#   MIGRATIONS_IMAGE_REPOSITORY / MIGRATIONS_IMAGE_TAG (tag defaults to SERVER_IMAGE_TAG:
#   the images are published in lockstep under the same version tag)
# Examples:
#   SERVER_IMAGE_TAG=1.2.0-snapshot ci/up.sh       # a published dev build (or "1.1.0")
#   SERVER_IMAGE_REPOSITORY=localhost/ister-server SERVER_IMAGE_TAG=dev \
#     SERVER_IMAGE_PULL_POLICY=Never ci/up.sh      # a locally built, kind-loaded image

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CHART_DIR=$(dirname "$SCRIPT_DIR")
TESTDATA_DIR="${TESTDATA_DIR:-$(dirname "$CHART_DIR")/testdata}"
CLUSTER_NAME="${CLUSTER_NAME:-ister}"
NAMESPACE="${NAMESPACE:-ister}"
RELEASE="${RELEASE:-ister}"

[ -d "$TESTDATA_DIR" ] || { echo "testdata not found at $TESTDATA_DIR (set TESTDATA_DIR)" >&2; exit 1; }

echo "==> Generating media fixtures in $TESTDATA_DIR"
(
  cd "$TESTDATA_DIR"
  # create_mkv.sh runs without `set -e` and its exit status is that of its last
  # statement, so it is no reliable success signal; gate on the output instead.
  ./create_mkv.sh || true
  ./create_books.sh
  ./create_comics.sh
  # The feed is served in-cluster by ci/podcast-feed.yaml under this name.
  ./create_podcast_feed.sh http://podcast-feed:8080
  [ "$(find node1/disk1 -name '*.mkv' | wc -l)" -gt 0 ] || { echo "no mkv fixtures generated" >&2; exit 1; }
)

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "==> Reusing kind cluster $CLUSTER_NAME"
else
  echo "==> Creating kind cluster $CLUSTER_NAME"
  # ci/kind-config.yaml mounts ./testdata relative to the working directory.
  (cd "$(dirname "$TESTDATA_DIR")" && kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/kind-config.yaml")
fi

echo "==> Deploying the mock OIDC issuer, podcast feed server and external-API mock"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "$NAMESPACE" -f "$SCRIPT_DIR/mock-oidc.yaml"
kubectl apply -n "$NAMESPACE" -f "$SCRIPT_DIR/podcast-feed.yaml"
kubectl apply -n "$NAMESPACE" -f "$SCRIPT_DIR/mock-external.yaml"
kubectl wait -n "$NAMESPACE" --for=condition=Available deploy/mock-oidc deploy/podcast-feed deploy/mock-external --timeout=180s

HELM_SET_ARGS=()
[ -n "${SERVER_IMAGE_REPOSITORY:-}" ] && HELM_SET_ARGS+=(--set "server.image.repository=$SERVER_IMAGE_REPOSITORY")
[ -n "${SERVER_IMAGE_TAG:-}" ] && HELM_SET_ARGS+=(--set "server.image.tag=$SERVER_IMAGE_TAG")
[ -n "${SERVER_IMAGE_PULL_POLICY:-}" ] && HELM_SET_ARGS+=(--set "server.image.pullPolicy=$SERVER_IMAGE_PULL_POLICY")
MIGRATIONS_IMAGE_TAG="${MIGRATIONS_IMAGE_TAG:-${SERVER_IMAGE_TAG:-}}"
[ -n "${MIGRATIONS_IMAGE_REPOSITORY:-}" ] && HELM_SET_ARGS+=(--set "flyway.image.repository=$MIGRATIONS_IMAGE_REPOSITORY")
[ -n "$MIGRATIONS_IMAGE_TAG" ] && HELM_SET_ARGS+=(--set "flyway.image.tag=$MIGRATIONS_IMAGE_TAG")
[ -n "${SERVER_IMAGE_PULL_POLICY:-}" ] && HELM_SET_ARGS+=(--set "flyway.image.pullPolicy=$SERVER_IMAGE_PULL_POLICY")

echo "==> Installing the chart${SERVER_IMAGE_TAG:+ (server image tag: $SERVER_IMAGE_TAG)}"
(
  cd "$CHART_DIR"
  helm dependency build
  helm upgrade --install "$RELEASE" . -n "$NAMESPACE" -f ci/values-ci.yaml \
    ${HELM_SET_ARGS[@]+"${HELM_SET_ARGS[@]}"} --wait --timeout 15m
)

echo "==> Waiting for everything to be ready"
kubectl wait -n "$NAMESPACE" --for=condition=Ready pod --all --timeout=10m
kubectl get pods -n "$NAMESPACE"

echo "==> Up. Run ci/e2e.sh for the API e2e, or ci/e2e/forward-for-player.sh for the player tests."
