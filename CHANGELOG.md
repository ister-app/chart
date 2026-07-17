# Changelog

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

