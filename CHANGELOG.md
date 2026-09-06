# Changelog

## ister-chart v0.5.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 3.4.1 |
| website | `ghcr.io/ister-app/player` | 2.7.1 |
| migrations | `ghcr.io/ister-app/migrations` | 3.4.1 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Fixes

- fix(ci): push main before the tag, keep third-party majors off automerge ([`07fc539`](https://github.com/ister-app/chart/commit/07fc539))
- fix(ci): give the e2e database 1Gi so postgres survives the player's tour ([`b669eed`](https://github.com/ister-app/chart/commit/b669eed))
- fix(ci): wait for the per-file analysis before the scan asserts ([`03557f4`](https://github.com/ister-app/chart/commit/03557f4))

### Dependency updates

- chore(deps): update ghcr.io/ister-app/player docker tag to v2 ([`f5ae445`](https://github.com/ister-app/chart/commit/f5ae445))
- chore(deps): update dependency helm to v4 ([`d178676`](https://github.com/ister-app/chart/commit/d178676))
- chore(deps): update ghcr.io/ister-app/server docker tag to v3.4.1 ([`123fc10`](https://github.com/ister-app/chart/commit/123fc10))
- chore(deps): update ghcr.io/ister-app/player docker tag to v1.19.0 ([`2c74b58`](https://github.com/ister-app/chart/commit/2c74b58))
- chore(deps): update dependency helm to v3.21.4 ([`32e0a2a`](https://github.com/ister-app/chart/commit/32e0a2a))

### Other

- ci: run Renovate three passes per day so every automerge lands ([`7609f5a`](https://github.com/ister-app/chart/commit/7609f5a))
- ci: run Renovate self-hosted and release once a day after the app releases ([`6237d36`](https://github.com/ister-app/chart/commit/6237d36))
- chore(ci): merge renovate updates without PRs and release on a daily schedule ([`eec594c`](https://github.com/ister-app/chart/commit/eec594c))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.5.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.5.0...v0.5.1

## ister-chart v0.5.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 3.0.0 |
| website | `ghcr.io/ister-app/player` | 1.4.0 |
| migrations | `ghcr.io/ister-app/migrations` | 3.0.0 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Features

- feat: bake last_update frontmatter into the docs zip ([`7eb5d9c`](https://github.com/ister-app/chart/commit/7eb5d9c))

### Fixes

- fix(ci): drive the scan with scanLibraries and deploy server 3.0.0 ([`bac9a05`](https://github.com/ister-app/chart/commit/bac9a05))
- fix(ci): publish the e2e API port instead of tunnelling it ([`b1ff654`](https://github.com/ister-app/chart/commit/b1ff654))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.5.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.4.4...v0.5.0

## ister-chart v0.4.4

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 2.2.0 |
| website | `ghcr.io/ister-app/player` | 1.4.0 |
| migrations | `ghcr.io/ister-app/migrations` | 2.2.0 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Fixes

- fix(database): widen internal-db probe timeouts so load spikes don't kill postgres ([`f7a03fa`](https://github.com/ister-app/chart/commit/f7a03fa))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.4.4
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.4.3...v0.4.4

## ister-chart v0.4.3

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 2.2.0 |
| website | `ghcr.io/ister-app/player` | 1.4.0 |
| migrations | `ghcr.io/ister-app/migrations` | 2.2.0 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Other

- docs: add SEO descriptions and link the published docs site ([`de24bf5`](https://github.com/ister-app/chart/commit/de24bf5))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.4.3
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.4.2...v0.4.3

## ister-chart v0.4.2

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 2.2.0 |
| website | `ghcr.io/ister-app/player` | 1.4.0 |
| migrations | `ghcr.io/ister-app/migrations` | 2.2.0 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Dependency updates

- chore(deps): update github actions (major) (actions/cache, actions/checkout, azure/setup-helm, helm) ([`90913a5`](https://github.com/ister-app/chart/commit/90913a5))
- chore(deps): update ghcr.io/ister-app/server docker tag to v2.2.0 ([`2eeb782`](https://github.com/ister-app/chart/commit/2eeb782))
- chore(deps): update ghcr.io/ister-app/player docker tag to v1.4.0 ([`fccab07`](https://github.com/ister-app/chart/commit/fccab07))
- chore(deps): update dependency helm to v3.21.3 ([`5043495`](https://github.com/ister-app/chart/commit/5043495))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.4.2
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.4.1...v0.4.2

## ister-chart v0.4.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 2.0.1 |
| website | `ghcr.io/ister-app/player` | 1.0.0 |
| migrations | `ghcr.io/ister-app/migrations` | 2.0.1 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Other

- ci: mint an admin token for the admin-gated e2e mutations ([`ecad96d`](https://github.com/ister-app/chart/commit/ecad96d))
- ci: add an admin client mapping to the mock OIDC issuer ([`9545e54`](https://github.com/ister-app/chart/commit/9545e54))
- ci: serve fixture-aware metadata from the external-API mock ([`4dae8f1`](https://github.com/ister-app/chart/commit/4dae8f1))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.4.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.4.0...v0.4.1

## ister-chart v0.4.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 2.0.1 |
| website | `ghcr.io/ister-app/player` | 1.0.0 |
| migrations | `ghcr.io/ister-app/migrations` | 2.0.1 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Features

- feat: ship the admin docs as a zip on every release ([`330275a`](https://github.com/ister-app/chart/commit/330275a))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.4.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.3.1...v0.4.0

## ister-chart v0.3.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 2.0.1 |
| website | `ghcr.io/ister-app/player` | 1.0.0 |
| migrations | `ghcr.io/ister-app/migrations` | 2.0.1 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Dependency updates

- fix(deps): bump the server (and with it migrations) to 2.0.1 ([`fdfec34`](https://github.com/ister-app/chart/commit/fdfec34))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.3.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.3.0...v0.3.1

## ister-chart v0.3.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 2.0.0 |
| website | `ghcr.io/ister-app/player` | 1.0.0 |
| migrations | `ghcr.io/ister-app/migrations` | 2.0.0 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Features

- feat: full-coverage e2e — all media types, mocked external sources, player reuse ([`0c63b67`](https://github.com/ister-app/chart/commit/0c63b67))

### Fixes

- fix: give CACHE_DIR the trailing slash the server expects ([`f88792a`](https://github.com/ister-app/chart/commit/f88792a))

### Dependency updates

- fix(deps): bump the server (and with it migrations) to 2.0.0 ([`47736c2`](https://github.com/ister-app/chart/commit/47736c2))
- fix(deps): bump typesense to 30.2 and the CI/test images ([`66e24e2`](https://github.com/ister-app/chart/commit/66e24e2))

### Other

- docs: use the lowercase snapshot tag form in the pinning examples ([`1b6408f`](https://github.com/ister-app/chart/commit/1b6408f))
- docs: describe the e2e scenario layout and CI-only mock pods ([`1d368c2`](https://github.com/ister-app/chart/commit/1d368c2))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.3.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.2.2...v0.3.0

## ister-chart v0.2.2

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 1.0.0 |
| website | `ghcr.io/ister-app/player` | 1.0.0 |
| migrations | `ghcr.io/ister-app/migrations` | 1.0.0 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 29.0 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Fixes

- fix: track server appVersion for the migrations image ([`c884ee8`](https://github.com/ister-app/chart/commit/c884ee8))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.2.2
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.2.1...v0.2.2

## ister-chart v0.2.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 1.0.0 |
| website | `ghcr.io/ister-app/player` | 1.0.0 |
| migrations | `ghcr.io/ister-app/migrations` | main |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 29.0 |
| rabbitmq | subchart `bitnamicharts/rabbitmq` | 16.0.14 |

### Other

- Fix helm test: drop hook-succeeded so --logs can read the test pod ([`f6f4447`](https://github.com/ister-app/chart/commit/f6f4447))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 0.2.1
```

