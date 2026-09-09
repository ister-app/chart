# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Helm chart (and nothing else) for the ister media server. The application code lives in
sibling repos in the `ister-app` GitHub org: `server` (Spring Boot backend), `player` (web
frontend), `migrations` (Flyway), and `testdata` (media fixtures used by the e2e). Their images
are published to `ghcr.io/ister-app/*`.

## Commands

```sh
helm lint . -f values-dev.yaml --set server.tmdbApiKey=x
helm template ister . -f ci/values-ci.yaml             # values.schema.json is enforced on every render
helm package .

ci/release-notes.sh <new-version> <previous-tag> && cat RELEASE_NOTES.md   # runs locally
ci/build-docs.sh 0.0.0-local                               # the docs zip, runs locally
```

There are several value profiles and CI renders all of them; a change to `values.yaml` or a
template must survive `values-dev.yaml`, `values-production.example.yaml`, `ci/values-ci.yaml`
(with the `ci/values-ingress-nginx.yaml` / `ci/values-gateway-envoy.yaml` overlays),
`ci/values-render-full.yaml` (every optional resource on) and the all-external permutation (no
bundled datastores) spelled out in `.github/workflows/ci.yml`. kubeconform validates the
renders, with the datreeio CRD catalog for the Gateway API resources.

Full e2e on kind (needs kind, helm, jq, ffmpeg, zip, a container runtime, and the testdata repo
cloned as a sibling):

```sh
make up          # fixtures + kind + mock-oidc/podcast-feed/mock-external + helm install
make e2e         # ci/e2e.sh: the scenario scripts in ci/e2e/, in order
make player-e2e  # the player repo's Flutter integration tests (needs ../player + flutter)
make down
make up EXPOSURE=ingress-nginx && make e2e-ingress   # through a real ingress controller
```

`ci/e2e.sh` takes `E2E_API_URL` + `E2E_CURL_ARGS` to reach the API through an ingress or
Gateway instead of a port-forward; `ci/up.sh` takes `EXPOSURE=ingress-nginx|gateway-envoy`
and installs that controller with `ci/exposure/<name>.sh` plus `ci/values-<name>.yaml`. CI
runs both variants (streaming scenario only) next to the full NodePort suite, and an
`upgrade` job that installs the previous release from ghcr and upgrades to the working
tree.

`ci/e2e.sh` sources `ci/e2e/lib.sh` and runs the numbered scenarios (scan, metadata enrichment,
podcast, HLS streaming with a real transcode, books, search, watch status); select with
`E2E_ONLY='30-*'`/`E2E_SKIP`. `ci/up.sh` is idempotent and takes image pins
(`SERVER_IMAGE_TAG=1.2.0-SNAPSHOT`, or a locally built image with
`SERVER_IMAGE_REPOSITORY=localhost/... SERVER_IMAGE_PULL_POLICY=Never` after a `kind load`).
`helm test ister -n ister --logs` runs the shipped smoke test alone.

**CI-only pods** (`ci/*.yaml`, not part of the chart): `mock-oidc.yaml` (JWT issuer),
`podcast-feed.yaml` (serves the generated feed), and `mock-external.yaml` — a WireMock pod
serving every external metadata source (TMDB, MusicBrainz, Cover Art Archive, Open Library,
Wikidata/Wikipedia, Commons, iTunes) under path prefixes, wired to the server through
`server.extraEnv` in `ci/values-ci.yaml`. The `15-metadata` scenario asserts enrichment lands
and that zero events dead-letter, so an unstubbed call fails CI — extend the stubs when the
server grows a new external call.

## Architecture

**Everything backing the server is bundled-or-external.** PostgreSQL has three modes
(`database.mode`: `internal` | `cnpg` | `external`), RabbitMQ and Typesense two (`*.enabled` plus
an `external*` block). This is the chart's central design constraint, and the way it stays
manageable is a **single Secret shape**: all three database modes produce a Secret with the keys
`host`, `port`, `dbname`, `user`, `password` — the shape CNPG generates for its `<cluster>-app`
Secret, which the `internal` and `external` modes hand-write to match. Nothing downstream ever
branches on `database.mode`. Preserve that when touching `templates/secrets.yaml` or
`ister.databaseSecretName` in `_helpers.tpl`.

**Passwords are generated once and preserved** via `lookup` against the live cluster
(`templates/secrets.yaml`). Without it every `helm upgrade` would mint a new password and lock the
app out of its own database. This is why `helm template` and `helm install` can disagree.

**That preservation does not survive GitOps**, and it is the single most expensive thing to
rediscover here. Argo CD, Flux and `helm template | kubectl apply` all render without cluster
access, so `lookup` returns nothing and every sync mints a fresh secret: PostgreSQL keeps the
first password in its volume and the server then fails with `password authentication failed`,
and everything else restarts on every commit through the `checksum/secrets` annotation. The
answer is an explicit value or an `existingSecret`; `NOTES.txt` names which values were
generated so an operator finds out at install time rather than on the third sync.

**Flyway is an init container on the server pod**, not a Helm hook. A `pre-install` hook cannot
work: in `internal`/`cnpg` mode the database is created by the same release, so the hook would wait
for a database Helm has not created yet.

**Server pods share one env template.** `ister.serverCommonEnv` in `_helpers.tpl` renders
everything every server pod needs (database, broker, search, OIDC, TMDB, cluster name,
external service URLs); `server-deployment.yaml` adds the per-node parts (name, URL, cache,
libraries, directories) and `helper-deployments.yaml` renders one Deployment + Service per
`helpers[]` entry with the helper-node env (`ister.helperEnv`) instead of libraries. Hardware
acceleration (`ister.hwaccel*`, `ister.serverPodSecurityContext`, `ister.serverResources`)
is applied the same way to both. A new server-wide env var belongs in the common template,
a new per-node one in both callers.

**Images all go through `ister.image`** (`_helpers.tpl`), which takes a `{repository, tag, digest}`
map and prefers the digest. Every image in the chart — including the Flyway wait container and the
`helm test` curl image — is declared as such a map in `values.yaml`, never hardcoded in a template.
That is load-bearing: Renovate's `helm-values` manager only sees the structured form, and only in
`values.yaml`.

**RabbitMQ is the chart's own StatefulSet** (`templates/rabbitmq.yaml`, official `rabbitmq` image),
not a subchart any more: the Bitnami chart had to be pinned to the unmaintained `bitnamilegacy`
mirror. Its Secret (`rabbitmq-password`, `rabbitmq-erlang-cookie`) is generated and preserved
like the others. There are no chart dependencies left, so `helm dependency build` is a no-op.

## Releasing

Automatic, and the details matter before you touch `Chart.yaml`:

- **Once a day, after the apps.** `release.yml` has no schedule of its own; it only runs on
  `workflow_dispatch`, and `.github/workflows/renovate.yml` dispatches it once a day (cron
  06:00 UTC, which GitHub starts hours late in practice). Before that, `renovate.yml` polls the
  public `release.yml` runs of `ister-app/server` and `ister-app/player` until today's have
  finished (up to 4h, then it goes ahead anyway), so a night on which both released yields one
  chart version, not two. A `changes` job in `release.yml` diffs `Chart.yaml`, `values.yaml`,
  `values.schema.json`, `templates/` and `doc/` against the previous tag and skips the whole
  workflow when nothing moved (`force=false`, what `renovate.yml` passes; the Actions-tab
  button defaults to `force=true`). Everything since the previous tag ships as one version,
  after the full CI passes on main.
- **Renovate is self-hosted** (`renovate.yml`, on the `RENOVATE_TOKEN` PAT secret with `repo` +
  `workflow` scope, falling back to `GITHUB_TOKEN`), not the Mend app, and it does not open
  PRs: `automergeType: "branch"` + `ignoreTests: true` in `renovate.json` means an automerged
  bump is pushed as a `renovate/*` branch and fast-forwarded into main in the same run,
  untested. The release is the gate. `ci.yml` has no push trigger. First-party
  (`ghcr.io/ister-app/*`) bumps automerge at every level, majors included; third-party majors
  keep `automerge: false` and still get a PR (rule order in `packageRules` matters there).
  Action bumps are `chore(deps)` and grouped, and they need the PAT: `GITHUB_TOKEN` may not
  edit `.github/workflows/`.
- `Chart.yaml` `version` and `appVersion` are **written by `.github/workflows/release.yml`** — never
  bump them by hand. `appVersion` is derived from `values.yaml` `server.image.tag`.
- The bump level comes from the commit messages since the last tag: `feat!`/`BREAKING CHANGE` →
  major, `feat` → minor, everything else (including Renovate's `fix(deps):`) → patch. So commit
  messages are functional here, not decoration.
- `server` and `player` have **independent version lines** in `values.yaml`; they do not move in
  lockstep. `migrations` is the exception: it publishes the same semver as the server, so its
  `flyway.image.tag` is left **empty** and `ister.image` falls back to `.Chart.AppVersion` (which
  is `server.image.tag`). Renovate bumping the server therefore bumps migrations too — one source
  of truth. `ci/release-notes.sh` mirrors that fallback so the migrations row is never blank.
- Renovate (`renovate.json`), not Dependabot — Dependabot's docker manager cannot tell two images
  in one `values.yaml` apart when they share a tag string (dependabot-core#6891).
- Every release also ships `ister-chart-docs-<version>.zip`, built by `ci/build-docs.sh` from
  `doc/admin/{en,nl}/` (the player repo's `doc/` layout). The values reference in each chapter is
  an **empty `VALUES:BEGIN`/`VALUES:END` marker pair in git** that the script fills from
  `values.yaml` at build time — never commit content between the markers, and never spell the
  literal markers out anywhere else in `doc/` (the script fills every pair it finds). `doc/` is
  `.helmignore`d, so it never ends up in the chart tgz; a `doc/**` change does trigger a release.

`server` and `player` publish semver tags and are pinned independently in `values.yaml`;
Renovate bumps each from there, and neither number belongs in prose that goes stale.
`migrations` has no `tag` of its own — see the appVersion note above.

## Conventions

- Nothing secret goes in a values file. Every credential has an `existingSecret` escape hatch, and
  all of them are hashed into a `checksum/secrets` pod annotation so rotating a Secret restarts the
  pod. Keep new credentials in `templates/secrets.yaml` for that reason.
- Comments in this repo explain *why*, especially where a template guards against a real failure
  (`server.enableServiceLinks`, the RWO cache PVC and `replicaCount`, the trailing slash on
  `mountPath`). If you change such a line, the comment above it is part of the change.
- `values.schema.json` is the values contract and is enforced on every render — a new value goes in
  both files or neither.
