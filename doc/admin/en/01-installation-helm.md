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
| RabbitMQ | The message broker (Bitnami subchart) | yes (`rabbitmq.enabled: true`) |
| Typesense | The search engine | yes (`typesense.enabled: true`) |
| Flyway | Database migrations (`ghcr.io/ister-app/migrations`) | runs as an init container |

The defaults deploy a self-contained ister with no ingress and no media volumes — enough
to try it out, not a production setup.

## Prerequisites

- A Kubernetes cluster and Helm 3.
- A [TMDB API key](https://www.themoviedb.org/settings/api) for movie/show metadata.
- An OIDC issuer (for example Keycloak) — ister does not manage users itself.
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

`true` deploys the Bitnami RabbitMQ subchart (everything under `rabbitmq:` is passed
straight to it). `false` uses the `externalRabbitmq` block instead — its `existingSecret`
needs the key `rabbitmq-password`.

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

## Ingress

`ingress.enabled: true` publishes the player at `/` and the API at `server.contextPath`
(default `/api`) on `ingress.host`, with TLS via cert-manager when
`ingress.tls.certIssuer` is set. `ingress.wellKnown.enabled` additionally serves
`/.well-known/ister` for client discovery — implemented as an ingress-nginx
server-snippet, which modern ingress-nginx disables by default
(`allow-snippet-annotations`); enable that on the controller first.

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
