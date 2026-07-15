# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Helm chart (and nothing else) for the ister media server. The application code lives in
sibling repos in the `ister-app` GitHub org: `server` (Spring Boot backend), `player` (web
frontend), `migrations` (Flyway), and `testdata` (media fixtures used by the e2e). Their images
are published to `ghcr.io/ister-app/*`.

## Commands

```sh
helm dependency build                                  # required first — pulls the RabbitMQ subchart

helm lint . -f values-dev.yaml --set server.tmdbApiKey=x
helm template ister . -f ci/values-ci.yaml             # values.schema.json is enforced on every render
helm package .

ci/release-notes.sh 0.3.0 v0.2.0 && cat RELEASE_NOTES.md   # release notes, runs locally
```

There are four value profiles and CI renders all of them; a change to `values.yaml` or a template
must survive `values-dev.yaml`, `values-production.example.yaml`, `ci/values-ci.yaml`, and the
all-external permutation (no bundled datastores) spelled out in `.github/workflows/ci.yml`.

Full e2e on kind (needs kind, jq, ffmpeg, a container runtime) — the exact sequence is in
README.md under "CI". `helm test ister -n ister --logs` runs the shipped smoke test alone.

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

**Flyway is an init container on the server pod**, not a Helm hook. A `pre-install` hook cannot
work: in `internal`/`cnpg` mode the database is created by the same release, so the hook would wait
for a database Helm has not created yet.

**Images all go through `ister.image`** (`_helpers.tpl`), which takes a `{repository, tag, digest}`
map and prefers the digest. Every image in the chart — including the Flyway wait container and the
`helm test` curl image — is declared as such a map in `values.yaml`, never hardcoded in a template.
That is load-bearing: Renovate's `helm-values` manager only sees the structured form, and only in
`values.yaml`.

**The RabbitMQ subchart's resource names are reproduced** in `_helpers.tpl`
(`ister.rabbitmqSubchartFullname`) because its Service and Secret are named by *its* fullname
template, not ours. It also pins `bitnamilegacy/rabbitmq` + `allowInsecureImages`, because Bitnami
stopped publishing to `docker.io/bitnami` and the subchart's own default tag 404s.

## Releasing

Automatic, and the details matter before you touch `Chart.yaml`:

- `Chart.yaml` `version` and `appVersion` are **written by `.github/workflows/release.yml`** — never
  bump them by hand. `appVersion` is derived from `values.yaml` `server.image.tag`.
- The bump level comes from the commit messages since the last tag: `feat!`/`BREAKING CHANGE` →
  major, `feat` → minor, everything else (including Renovate's `fix(deps):`) → patch. So commit
  messages are functional here, not decoration.
- The three ister images have **independent version lines** in `values.yaml`; they do not move in
  lockstep, and `appVersion` speaks only for the server.
- Renovate (`renovate.json`), not Dependabot — Dependabot's docker manager cannot tell two images
  in one `values.yaml` apart when they share a tag string (dependabot-core#6891).

`server` and `player` now publish semver tags: `values.yaml` pins both at `1.0.0` and Renovate
bumps them from there. `migrations` still publishes only `:main`, so its `tag` stays `"main"`
until it cuts a real release.

## Conventions

- Nothing secret goes in a values file. Every credential has an `existingSecret` escape hatch, and
  all of them are hashed into a `checksum/secrets` pod annotation so rotating a Secret restarts the
  pod. Keep new credentials in `templates/secrets.yaml` for that reason.
- Comments in this repo explain *why*, especially where a template guards against a real failure
  (`server.enableServiceLinks`, the RWO cache PVC and `replicaCount`, the trailing slash on
  `mountPath`). If you change such a line, the comment above it is part of the change.
- `values.schema.json` is the values contract and is enforced on every render — a new value goes in
  both files or neither.
