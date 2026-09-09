---
description: Install the Ister self-hosted media server on Kubernetes with Helm, including bundled PostgreSQL, RabbitMQ and Typesense or your own services.
---

# Installing ister with Helm

This chapter explains how the ister Helm chart works and how to install it. The chart
deploys the full ister media server: the API server, the web player, and — unless you
bring your own — PostgreSQL, RabbitMQ and Typesense.

## What the chart deploys

| Component | What it is | Bundled by default? |
|---|---|---|
| server | The Spring Boot backend (`ghcr.io/ister-app/server`) | always |
| website | The web player (`ghcr.io/ister-app/player`) | always |
| PostgreSQL | The database | yes (`database.mode: internal`) |
| RabbitMQ | The message broker (official image, single node) | yes (`rabbitmq.enabled: true`) |
| Typesense | The search engine | yes (`typesense.enabled: true`) |
| Flyway | Database migrations (`ghcr.io/ister-app/migrations`) | runs as an init container |

The defaults deploy a self-contained ister with no ingress and no media volumes — enough
to try it out, not a production setup.

## Prerequisites

- A Kubernetes cluster and Helm 3.
- A [TMDB API key](https://www.themoviedb.org/settings/api) for movie/show metadata.
- An OIDC issuer (for example Keycloak) — ister does not manage users itself. It has to
  be set up a particular way; see [Setting up the identity provider](02-identity-provider.md).
- For `database.mode: cnpg`: the [CloudNativePG](https://cloudnative-pg.io/) operator.
- For ingress with TLS: an ingress controller and, optionally, cert-manager.

## Installing

The chart is published as an OCI artifact:

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister \
  --namespace ister --create-namespace \
  --set server.tmdbApiKey=<your-key> \
  --set server.oidc.url=https://keycloak.example.com/realms/auth
```

For anything beyond a first try, start from `values-production.example.yaml` in the
[chart repository](https://github.com/ister-app/chart) and install with `-f`. Pin a chart
version with `--version`; a GitHub Release exists for every chart version with release
notes listing the exact image versions it deploys.

## Bundled or external datastores

Everything backing the server can either be deployed by the chart or pointed at an
existing service. Whatever you choose, the templates downstream never notice the
difference — that is the chart's central design rule.

### PostgreSQL — `database.mode`

- `internal` — a single postgres Deployment + PVC. Development only: one instance, no
  backups.
- `cnpg` — a CloudNativePG `Cluster` (3 instances by default, anti-affinity, optional
  Barman Cloud backups to S3 under `database.cnpg.backup`). Requires the CNPG operator.
- `external` — an existing PostgreSQL, configured under `database.external`.

All three modes converge on **one Secret with the keys `host`, `port`, `dbname`, `user`,
`password`** — the shape CNPG generates for its `<cluster>-app` Secret, which the other
two modes hand-write to match. If you bring your own Secret (`existingSecret`), it must
have exactly those keys; for a CNPG cluster managed outside this chart, its `<cluster>-app`
Secret already does.

### RabbitMQ — `rabbitmq.enabled`

`true` deploys a single-node RabbitMQ StatefulSet on the official `rabbitmq` image
(ister only uses the broker for pass-through work, so nothing needs clustering); the
password and Erlang cookie are generated once, or come from `rabbitmq.auth.existingSecret`
(keys `rabbitmq-password`, `rabbitmq-erlang-cookie`). `false` uses the `externalRabbitmq`
block instead — its `existingSecret` needs the key `rabbitmq-password`.

Upgrading from a chart before 1.0, which shipped the Bitnami subchart: the old
StatefulSet, Service and PVC named `<release>-rabbitmq` are not adopted. Delete them (the
queues hold pass-through work only) before upgrading, or run the upgrade and delete the
leftover PVC afterwards; the server reconnects to the new broker on its own.

### Typesense — `typesense.enabled`

`true` deploys Typesense with its own PVC. `false` uses `typesense.external` — its
`existingSecret` needs the key `api-key`.

## Secrets and passwords

- **Nothing secret belongs in a values file.** Every credential has an `existingSecret`
  escape hatch; use it (or a secret manager) anywhere that matters.
- **Generated passwords survive upgrades.** When you let the chart generate a password,
  it looks up the live Secret on upgrade and keeps the existing value — otherwise every
  `helm upgrade` would lock the server out of its own database. This is also why
  `helm template` output differs from what `helm install` actually applies.
- **...but not under GitOps.** Argo CD, Flux and `helm template | kubectl apply` render
  without access to the cluster, so that lookup finds nothing and every sync generates a
  new password. PostgreSQL keeps the first one in its volume and the server then fails
  with `password authentication failed`; everything else restarts on every commit through
  the `checksum/secrets` annotation. Deploying that way means setting
  `database.internal.password`, `rabbitmq.auth.password` and `typesense.apiKey`
  explicitly, or pointing the matching `existingSecret` at a Secret you manage.
- **Rotating a Secret restarts the server.** All credentials are hashed into a
  `checksum/secrets` pod annotation, so a changed Secret rolls the Deployment.

## Database migrations

Flyway runs as an **init container on the server pod** (preceded by a `wait-for-db`
container), so the server can never start against an unmigrated schema. It is not a Helm
hook on purpose: with a bundled database, a pre-install hook would wait for a database
that Helm has not created yet. The migrations image publishes the same version as the
server, so `flyway.image.tag` stays empty and follows the server version automatically.

## Media libraries and volumes

Two value lists connect the server to your media:

- `server.libraries` — the libraries ister scans; each has a `name` and a `type`
  (`SHOW`, `MOVIE`, `MUSIC`, `BOOK`, `PODCAST`, `COMIC`).
- `server.mediaVolumes` — the volumes mounted into the server pod, each backed by exactly
  one of `hostPath`, `existingClaim` or `nfs`, and linked to a library via `library`
  (omit it for a mount-only volume). **No trailing slash on `mountPath`** — the scanner
  skips the tree if there is one.

Two more storage knobs matter:

- `cache` — a PVC for the server's cache directory (transcodes, images). It is
  `ReadWriteOnce` by default, which is why `server.replicaCount` must stay at 1 — the
  chart refuses to render more replicas unless you switch to `ReadWriteMany`.
- `server.tmp` — scratch space for transcoding. Disable it when `mountPath` falls inside
  one of your media volumes, or the dedicated volume shadows that path.

## Exposing it: Ingress or Gateway API

Both publish the player at `/` and the API at `server.contextPath` (default `/api`) on one
hostname; pick one.

- **Ingress** — `ingress.enabled: true` with `ingress.host`. `ingress.className` is empty
  by default (the cluster's default IngressClass); set it when you run several
  controllers. TLS via cert-manager when `ingress.tls.certIssuer` is set.
- **Gateway API** — `gateway.enabled: true` with `gateway.hostnames` and
  `gateway.parentRefs` (the Gateway and listener to attach to; the Gateway itself is
  yours and must allow routes from the chart's namespace). Works with Envoy Gateway,
  Cilium, Istio, Traefik's Gateway provider and the like.

Whatever fronts ister has to allow three things most proxies limit by default: unbounded
request bodies (helper nodes upload whole HLS segments and subtitle files), responses that
run for minutes to hours (HLS playback, a helper node reading a multi-GB source), and
websocket upgrades on `/api/graphql`. `ingress.controller` (`nginx` | `traefik` |
`haproxy`) renders the matching annotations from `ingress.proxy`; the HTTPRoute sets
`timeouts.request: 0s` on the `/api` rule (`gateway.apiTimeouts`). Traefik needs nothing
per Ingress, but its read timeouts are entrypoint settings
(`entryPoints.<name>.transport.respondingTimeouts`).

`/.well-known/ister`, the document clients fetch first (instance name, OIDC issuer, API
URL), is served by the website pod itself (`website.wellKnown`, default on), so it works
behind any controller, a NodePort or a port-forward. The older ingress-nginx snippet
(`ingress.wellKnown`) is still there for setups that rely on it.

The Services accept the usual knobs (`server.service`, `website.service`,
`typesense.service`: `type`, `nodePort`, `annotations`, `loadBalancerIP`, `ipFamilies`,
...). On an IPv6-primary cluster, give the website and Typesense Services
`ipFamilyPolicy: SingleStack` / `ipFamilies: [IPv4]` unless the player image is 2.8 or
newer: older images listen on IPv4 only, and an IPv6-only ClusterIP then answers 503.

## Helper nodes and hardware encoding

A second server pod can take the CPU-heavy work — HLS transcoding, intro/outro detection,
subtitle extraction and OCR — for the main server's directories without owning any media:
it reads the source over HTTP from the main server and uploads the result back. Declare
them under `helpers`, one entry per pod, each naming the main server's directories
(`mediaVolumes[].name`) it helps with and optionally which job families; the main server
can hand families off entirely with `server.helper.offloadJobs`. Set `server.clusterName`
so all pods present one cluster to clients. The helpers share the chart's database,
broker and search and need nothing else. See the server documentation, chapter
Multi-node, for how the work is shared.

Hardware encoding is `hwaccel` on the main server and on each helper: `type: vaapi`
(Intel/AMD) or `nvdec` (NVIDIA), and a way to hand the pod the GPU. Prefer a device
plugin (`hwaccel.resources`, for example `gpu.intel.com/i915: 1`, `amd.com/gpu: 1`,
`nvidia.com/gpu: 1`, or `squat.ai/dri: 1` with the generic device plugin) — unprivileged
and schedulable. `hwaccel.hostPath: true` mounts the device file from the node instead,
which the device cgroup only allows for a privileged container (`hwaccel.privileged`).
Add the node's `video`/`render` group ids to `hwaccel.supplementalGroups` when the device
is group-owned.

## Address families: dual-stack and IPv6-only clusters

The chart runs on an IPv4-only, a dual-stack or an IPv6-only cluster, with one caveat
that is the image's and not the chart's. Two separate things go wrong when a container
listens on IPv4 only, and it is worth keeping them apart:

1. **Its Service.** Without an explicit `ipFamilies`, a Service on an IPv6-primary
   cluster gets an IPv6 ClusterIP, and the container never answers there. That reads as
   a crashed application; it is a networking choice.
2. **Its probes.** kubelet aims an `httpGet` probe at the pod's *first* IP, which on such
   a cluster is the IPv6 one. The probe then fails against a pod that serves its Service
   perfectly well, and a liveness probe restarts it forever.

Where each component stands, measured on kind with `ipFamily: ipv4`, kind with
`ipFamily: ipv6`, and a dual-stack cluster:

| Component | IPv4-only | dual-stack, IPv6-primary | IPv6-only |
|---|---|---|---|
| server | works | works | works |
| PostgreSQL (internal) | works | works | works |
| RabbitMQ (AMQP) | works | works | works |
| Typesense | works | works | works |
| website | works | works | works |
| website, player pinned ≤ 2.7 | works | needs a Service pin | unreachable |

- **Typesense** listens dual-stack because `typesense.apiAddress` defaults to `::`. The
  image's own default is `0.0.0.0`, which fails both ways above. Set it back to
  `0.0.0.0` only on nodes that run with IPv6 disabled in the kernel.
- **The server, PostgreSQL and RabbitMQ's AMQP listener** bind `::` by themselves.
  RabbitMQ's management, Prometheus and Erlang-distribution listeners are IPv4-only, but
  nothing in this chart reaches them across the network: `rabbitmq-diagnostics` talks to
  the local node, and 127.0.0.1 exists in a pod on any cluster.
- **The web player** listens dual-stack from image 2.8, which is what the chart pins.
  Pin an older one and its nginx is IPv4-only again: on a dual-stack cluster its Service
  then needs

  ```yaml
  website:
    service:
      ipFamilyPolicy: SingleStack
      ipFamilies: [IPv4]
  ```

  and on an IPv6-only cluster it cannot be reached at all. The API is unaffected either
  way. Its readiness probe runs over `127.0.0.1` inside the container, so with such a pin
  the pod reports Ready even where its Service is dead — check the Service, not the pod,
  if the player does not load.

## Network policies and pod security

`networkPolicy.enabled: true` renders ingress-only NetworkPolicies: the datastores accept
traffic from this release's pods only, the server, helpers and website also from
`networkPolicy.ingressFrom` — add your ingress controller's or Gateway's namespace there,
and Prometheus for the monitor port. Egress stays open (metadata sources, podcast feeds,
your OIDC issuer). The pods pass the "restricted" Pod Security Standard; on OpenShift set
`runAsUser`/`fsGroup` to `null` in the `podSecurityContext` blocks so the SCC assigns
the UID.

## Operations

- **Upgrades**: `helm upgrade ister oci://ghcr.io/ister-app/charts/ister --version <v>`
  with your values file. Generated passwords are preserved (see above).
- **Smoke test**: `helm test ister -n ister --logs` runs the shipped connectivity test.
- **Monitoring**: `monitoring.enabled` renders a Prometheus Operator ServiceMonitor for
  the server's actuator; in `cnpg` mode, `database.cnpg.podMonitor` covers the database.
- **Uninstall**: the database, cache and Typesense PVCs are kept by default
  (`retain: true`) so an uninstall is not destructive; set `retain: false` where you
  want them purged with the release.

## Values reference

Every value the chart accepts, with its default. This table is generated from the
`values.yaml` of the release this documentation shipped with; `values.schema.json`
enforces the same contract on every render.

<!-- VALUES:BEGIN (generated by ci/build-docs.sh — do not edit between the markers) -->
<!-- VALUES:END -->
