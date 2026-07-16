# ister

Helm chart for the [ister](https://github.com/ister-app) media server: a Spring Boot
backend, a web frontend, PostgreSQL, RabbitMQ and Typesense.

## Install

Released charts are pushed to ghcr.io as OCI artifacts:

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.2.0 \
  -n ister --create-namespace -f values-production.yaml
```

From a checkout instead — which is what you want when changing the chart:

```sh
helm dependency build

# Development: everything self-contained, no ingress.
helm install ister . -f values-dev.yaml -n ister --create-namespace \
  --set server.tmdbApiKey=<key>

# Production: copy the example, fill in the placeholders, then install.
# values-production.yaml is gitignored, so your hostnames and paths stay local.
cp values-production.example.yaml values-production.yaml
helm upgrade --install ister . -f values-production.yaml -n ister --create-namespace
```

The chart does not create its namespace — use `--create-namespace`. (A templated
Namespace would be deleted again by `helm uninstall`, taking everything in it along.)

## Profiles

Each backing service can be bundled or external, so the same chart covers a laptop and
a real cluster.

| | bundled | external |
|---|---|---|
| PostgreSQL | `database.mode=internal` (one pod, no backups)<br>`database.mode=cnpg` (CloudNativePG, HA + Barman backups) | `database.mode=external` |
| RabbitMQ | `rabbitmq.enabled=true` (Bitnami subchart) | `rabbitmq.enabled=false` + `externalRabbitmq.*` |
| Typesense | `typesense.enabled=true` | `typesense.enabled=false` + `typesense.external.*` |

All three database modes expose the same Secret keys (`host`, `port`, `dbname`, `user`,
`password`), so nothing downstream branches on the mode. `cnpg` and `external` are what
you want in production; `internal` has no backups and no failover.

`database.mode=cnpg` needs the CloudNativePG operator, and `database.cnpg.backup` also
needs the barman-cloud plugin. `monitoring.enabled` needs the Prometheus Operator.

## Secrets

Nothing secret belongs in a values file. Create the Secrets yourself and point the chart
at them:

| value | Secret keys |
|---|---|
| `server.existingSecret` | `tmdb-api-key` |
| `typesense.existingSecret` | `api-key` |
| `externalRabbitmq.existingSecret` / `rabbitmq.auth.existingPasswordSecret` | `rabbitmq-password` |
| `database.external.existingSecret` | `host`, `port`, `dbname`, `user`, `password` |
| `database.cnpg.backup.existingSecret` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |

Passwords left empty are generated on install and preserved across upgrades (via
`lookup`). Passing them with `--set` instead puts them in your shell history.

Every credential the server reads is hashed into a `checksum/secrets` pod annotation, so
rotating a Secret actually restarts the pod.

## Media

`server.mediaVolumes` is both the mount list and the scanner config. Each entry is
mounted into the server, and entries with a `library` are also registered as
`APP_ISTER_DISK_DIRECTORIES_<i>_*`. Entries without one are mounted but not scanned
(scratch space, for instance).

```yaml
server:
  libraries:
    - name: shows
      type: SHOW          # SHOW | MOVIE | MUSIC | BOOK | PODCAST
  mediaVolumes:
    - name: shows
      library: shows
      mountPath: /mnt/shows
      hostPath: /srv/media/shows     # or: existingClaim, or: nfs
```

A `hostPath` entry pins the server to whichever node holds that path — set
`server.nodeSelector` to match, or use `existingClaim`/`nfs` to keep it schedulable.

## Migrating from the raw manifests

The manifests this chart replaces label their pods with `io.kompose.service` (a leftover
from `kompose convert`); the chart uses the standard `app.kubernetes.io/*` labels.
`spec.selector` on a Deployment is **immutable**, so the two cannot be reconciled — Helm
will fail with `field is immutable` until the old objects are gone.

Delete them first. This is a brief outage, not data loss: the media is on hostPaths and
the database is a separate CNPG cluster, neither of which is touched.

```sh
# 1. Stop Argo CD from re-creating them (or delete the Application first).
kubectl delete deployment ister-server ister-website -n ister
kubectl delete service ister-server-service ister-monitor-server-service ister-website-service -n ister
kubectl delete ingress ister-ingress -n ister
kubectl delete servicemonitor ister-service-monitor -n ister

# 2. The chart adopts the existing CNPG cluster (same name, ister-database) in place.
#    Create the Secrets it expects (see values-production.yaml), then:
helm upgrade --install ister . -f values-production.yaml -n ister
```

Typesense and RabbitMQ keep their data: point `typesense.persistence.existingClaim` at
the current `typesense-data` PVC, and either let the RabbitMQ subchart adopt the existing
`rabbitmq` release or leave the standalone one running and set `rabbitmq.enabled=false`.

Verify before committing to it:

```sh
helm template ister . -f values-production.yaml | kubectl apply --dry-run=server -f -
```

## Notes

- Flyway runs as an **init container** on the server, not a Helm hook. A `pre-install`
  hook cannot work here: in `internal`/`cnpg` mode the database is created by the same
  release, so the hook would wait for a database Helm has not created yet.
- `server.enableServiceLinks` must stay `false`. Kubernetes injects a `TYPESENSE_PORT`
  service-link variable that shadows Spring's `${TYPESENSE_PORT:8108}` placeholder.
- The cache PVC is `ReadWriteOnce`, so `server.replicaCount` > 1 fails the render unless
  you switch `cache.accessMode` to `ReadWriteMany`.
- PVCs are annotated `helm.sh/resource-policy: keep`, so `helm uninstall` does not delete
  your database. Set `*.retain=false` to opt out.
- `ingress.wellKnown` renders an ingress-nginx `server-snippet`. Modern ingress-nginx
  ships with `allow-snippet-annotations=false` and drops it silently.

## Develop

```sh
helm lint . -f values-dev.yaml --set server.tmdbApiKey=x
helm template ister . -f values-production.yaml | kubectl apply --dry-run=server -f -
helm test ister -n ister
```

## Releasing

Releases are automatic. Merging anything that touches the chart (`Chart.yaml`, `values.yaml`,
`values.schema.json`, `templates/`) runs `.github/workflows/release.yml`, which re-runs the
full CI on the merged commit and only then bumps, packages, pushes and publishes:

| commit | chart bump |
|---|---|
| `feat(...)!:` or `BREAKING CHANGE:` in the body | major |
| `feat:` | minor |
| everything else, including Renovate's `fix(deps):` | patch |
| `chore(deps):` (GitHub Actions bumps) | no release — `.github/` is not in the trigger paths |

`workflow_dispatch` takes an explicit `bump` if you need to override that.

The workflow writes the new version into `Chart.yaml`, sets `appVersion` to the **server**
image tag, generates the release notes, pushes `oci://ghcr.io/ister-app/charts/ister`, tags
`v<version>` and cuts a GitHub Release with the `.tgz` attached. `ci/release-notes.sh` builds
the notes from the commits since the previous tag, grouped by conventional-commit type, with a
table of the image versions the release actually deploys. It runs locally too:

```sh
ci/release-notes.sh 0.3.0 v0.2.0 && cat RELEASE_NOTES.md
```

### Versions

Three versions, three meanings:

- **chart version** (`Chart.yaml: version`) — this chart's own semver. Bumped by the release
  workflow, never by hand.
- **appVersion** (`Chart.yaml: appVersion`) — the server image version, mirrored onto pods as
  `app.kubernetes.io/version`. Derived, not authored.
- **image tags** (`values.yaml`) — `server`, `player` and `migrations` each have their own
  version line and move independently. They are the actual source of truth.

### Renovate

`renovate.json` keeps every image tag in `values.yaml`, the RabbitMQ subchart in `Chart.yaml`
and the pinned GitHub Actions up to date. Each image gets its own PR, CI (including the kind
e2e) runs on it, and patch/minor bumps automerge — so a new server release becomes a new chart
release without a human in the loop. Majors wait on the dependency dashboard.

Renovate rather than Dependabot because Dependabot's docker manager cannot tell two images in
one `values.yaml` apart when they carry the same tag string
([dependabot-core#6891](https://github.com/dependabot/dependabot-core/issues/6891), closed as
not planned) — it bumps both. With independent version lines for server and player, that breaks
the moment the two happen to land on the same version.

**Two things still have to be set up for this to work:**

1. **The app repos must publish semver tags.** `server` and `player` now do, and `values.yaml`
   pins both at `1.0.0` with Renovate taking over from there. `ghcr.io/ister-app/migrations`
   still publishes only `:main`, which is why its `tag` stays `"main"` — there is no version to
   pin to yet. To fix it, add semver tags to the migrations publish workflow the same way:

   ```yaml
   - uses: docker/metadata-action@v5
     with:
       images: ghcr.io/ister-app/migrations
       tags: |
         type=semver,pattern={{version}}
         type=semver,pattern={{major}}.{{minor}}
         type=ref,event=branch          # keeps publishing :main for dev
   ```

   Then set the tag in `values.yaml` to that first release once, and Renovate takes it from there.

2. **Repo settings.** Install the Renovate GitHub App on the org; enable "Allow auto-merge";
   protect `main` with CI as a required check, and let `github-actions` bypass it — the
   release workflow pushes the `chore(release):` commit back to `main`.

## CI

`.github/workflows/ci.yml` lints and renders every profile, then stands the whole stack up
on a kind cluster and tests that it actually works. It runs on push and PR, on a weekly
schedule (the dev profiles deploy mutable `:main` images and the kind/actions environment
moves regardless, so CI can go red without anyone touching this repo), on a
`repository_dispatch` of type `images-published` so the app repos can re-run it after
publishing new images, and via `workflow_call` from the release workflow — a chart is never
released on a red e2e.

Three levels of test:

- **`helm test`** — unauthenticated, ships with the chart, so users can run it against
  their own install. Checks actuator health, `/.well-known/ister`, the website, Typesense,
  and the `getServerInfo` GraphQL query. That last one reads the node registry from the
  database, so it proves Postgres is up, Flyway migrated, and the server registered itself.
- **`ci/e2e.sh`** — the real thing: mints a JWT and runs the scenario scripts in
  `ci/e2e/` in order: `10-scan` (every library type indexes: shows, movies, albums, books
  with audiobook chapters and media-overlay detection, comic series with page counts),
  `15-metadata` (enrichment through the mocked external sources actually lands, and zero
  events dead-letter), `20-podcast` (subscribe → refresh → download against the in-cluster
  `ci/podcast-feed.yaml` server), `30-streaming` (stream token → HLS master playlist → a
  real ffmpeg-transcoded segment), `40-books` (epub resources + reading-progress
  round-trip), `50-search` (Typesense, shows and movies) and `60-watch-status` (play queue
  heartbeat → recentlyWatched).
  This needs an OIDC issuer, because `scanLibrary` and every content query are
  `@PreAuthorize("hasRole('user')")` — hence `ci/mock-oidc.yaml`, a mock issuer minting
  tokens with a `roles: ["user"]` claim. All external metadata sources (TMDB, MusicBrainz,
  Cover Art Archive, Open Library, Wikidata/Wikipedia, Wikimedia Commons, iTunes) are
  served by `ci/mock-external.yaml`, a WireMock pod the server is pointed at via
  `server.extraEnv` in `ci/values-ci.yaml` — deterministic, offline, no rate limits, no
  real TMDB key. `E2E_ONLY='30-*'`/`E2E_SKIP` select scenarios during local iteration.
- **Player integration tests** — live in the `ister-app/player` repo
  (`integration_test/`) and run the real Flutter app against this same kind deployment:
  add-server flow, movie playback over HLS, audiobook and podcast playback, epub reading
  with progress sync, and read-aloud. Their CI job checks out this chart and reuses
  `ci/up.sh`. The tests reach the server on `localhost:8080` (the chart's default
  advertised `server.url`) via `ci/e2e/forward-for-player.sh`.

To run it locally (needs kind, helm, jq, ffmpeg, zip, and a container runtime; the
testdata repo cloned next to this one):

```sh
make up          # fixtures + kind cluster + mock-oidc + podcast-feed + chart install
make e2e         # the API e2e scenarios
make player-e2e  # the player's Flutter integration tests (needs ../player + flutter)
make down        # delete the kind cluster
```
