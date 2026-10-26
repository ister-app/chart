# Changelog

## ister-chart v2.2.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.7.0 |
| website | `ghcr.io/ister-app/player` | 2.17.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.7.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Fixes

- fix(server): sync server.config with server v5.7.0 ([`b4c4cc3`](https://github.com/ister-app/chart/commit/b4c4cc3))
- fix(server): sync server.config with server v5.6.0 ([`441671e`](https://github.com/ister-app/chart/commit/441671e))
- fix(server): sync server.config with server v5.5.0 ([`037287e`](https://github.com/ister-app/chart/commit/037287e))

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v5.7.0 ([`c062182`](https://github.com/ister-app/chart/commit/c062182))
- chore(deps): update ghcr.io/ister-app/player docker tag to v2.17.0 ([`90c1538`](https://github.com/ister-app/chart/commit/90c1538))
- chore(deps): update renovatebot/github-action action to v46.3.10 ([`45ea77e`](https://github.com/ister-app/chart/commit/45ea77e))
- chore(deps): update ghcr.io/ister-app/server docker tag to v5.6.0 ([`4724e2b`](https://github.com/ister-app/chart/commit/4724e2b))
- chore(deps): update ghcr.io/ister-app/player docker tag to v2.16.0 ([`6129630`](https://github.com/ister-app/chart/commit/6129630))
- chore(deps): update ghcr.io/ister-app/server docker tag to v5.5.0 ([`044db79`](https://github.com/ister-app/chart/commit/044db79))

### Server settings (server.config)

Server defaults not yet mirrored in `server.config` (set them there or via env):

- `app.ister.games.achievement-icon-max-bytes` = `512KB`
- `app.ister.games.save-max-bytes` = `512MB`
- `app.ister.games.save-retention` = `10`
- `app.ister.server.background-nice` = `10`
- `app.ister.server.nice-path` = `/usr/bin/nice`
- `app.ister.server.segment-detect.concurrency` = `1`
- `spring.http.clients.imperative.factory` = `jdk`

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 2.2.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v2.2.0...v2.2.1

## ister-chart v2.2.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.4.0 |
| website | `ghcr.io/ister-app/player` | 2.15.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.4.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Features

- feat(games): game tunables and Ludusavi manifest endpoint ([`c29a9f9`](https://github.com/ister-app/chart/commit/c29a9f9))

### Fixes

- fix(server): sync server.config with server v5.4.0 ([`b879200`](https://github.com/ister-app/chart/commit/b879200))
- fix(config): keep server.config at the pinned server's defaults ([`525d071`](https://github.com/ister-app/chart/commit/525d071))

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v5.4.0 ([`a8e0b7a`](https://github.com/ister-app/chart/commit/a8e0b7a))
- chore(deps): update ghcr.io/ister-app/player docker tag to v2.15.0 ([`8f83577`](https://github.com/ister-app/chart/commit/8f83577))
- chore(deps): update renovatebot/github-action action to v46.3.9 ([`f299556`](https://github.com/ister-app/chart/commit/f299556))

### Server settings (server.config)

- changed: `app.ister.upload.max-files-per-session` `20000` → `100000`

Server defaults not yet mirrored in `server.config` (set them there or via env):

- `app.ister.games.achievement-icon-max-bytes` = `512KB`
- `app.ister.games.save-max-bytes` = `512MB`
- `app.ister.games.save-retention` = `10`
- `app.ister.server.background-nice` = `10`
- `app.ister.server.nice-path` = `/usr/bin/nice`
- `app.ister.server.segment-detect.concurrency` = `1`

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 2.2.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v2.1.0...v2.2.0

## ister-chart v2.1.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.3.0 |
| website | `ghcr.io/ister-app/player` | 2.14.1 |
| migrations | `ghcr.io/ister-app/migrations` | 5.3.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Features

- feat(config): pin spring.threads.virtual.enabled in server.config ([`d7b8cf2`](https://github.com/ister-app/chart/commit/d7b8cf2))

### Fixes

- fix(server): sync server.config with server v5.3.0 ([`812db81`](https://github.com/ister-app/chart/commit/812db81))
- fix(config): spring.threads.virtual.enabled is baked into the server image, not a tunable ([`2f57984`](https://github.com/ister-app/chart/commit/2f57984))

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v5.3.0 ([`0df572d`](https://github.com/ister-app/chart/commit/0df572d))
- chore(deps): update github actions to v3.22.1 ([`b37a3ee`](https://github.com/ister-app/chart/commit/b37a3ee))
- chore(deps): update ghcr.io/ister-app/player docker tag to v2.14.1 ([`03dee55`](https://github.com/ister-app/chart/commit/03dee55))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 2.1.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v2.0.1...v2.1.0

## ister-chart v2.0.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.2.3 |
| website | `ghcr.io/ister-app/player` | 2.14.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.2.3 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Fixes

- fix(server): sync server.config with server v5.2.3 ([`bb4b19b`](https://github.com/ister-app/chart/commit/bb4b19b))

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v5.2.3 ([`809d06d`](https://github.com/ister-app/chart/commit/809d06d))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 2.0.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v2.0.0...v2.0.1

## ister-chart v2.0.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.2.2 |
| website | `ghcr.io/ister-app/player` | 2.14.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.2.2 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Breaking changes

- feat(server)!: expose tunable Spring properties as server.config ([`b193a29`](https://github.com/ister-app/chart/commit/b193a29))

### Features

- feat(ci): keep server.config in sync with the pinned server's defaults ([`69fe4d6`](https://github.com/ister-app/chart/commit/69fe4d6))
- feat(release): list server.config changes in the release notes ([`5af25fd`](https://github.com/ister-app/chart/commit/5af25fd))

### Fixes

- fix(ci): config-sync refreshes the header version without value changes ([`9f40800`](https://github.com/ister-app/chart/commit/9f40800))

### Dependency updates

- fix(deps): update ghcr.io/ister-app/server docker tag to v5.2.2 ([`96d7c3b`](https://github.com/ister-app/chart/commit/96d7c3b))
- chore(deps): update renovatebot/github-action action to v46.3.8 ([`a01acaa`](https://github.com/ister-app/chart/commit/a01acaa))

### Server settings (server.config)

- added: `app.ister.s3.ffmpeg-direct` = `false`
- added: `app.ister.s3.local-copy-max-bytes` = `2147483648`
- added: `app.ister.s3.presign-ttl` = `2h`
- added: `app.ister.server.TMDB.max-requests-per-second` = `30`
- added: `app.ister.server.blur-hash.chunk-size` = `500`
- added: `app.ister.server.cache-cleanup.cron` = `0 30 4 * * *`
- added: `app.ister.server.cache-cleanup.dry-run` = `true`
- added: `app.ister.server.cache-cleanup.enabled` = `true`
- added: `app.ister.server.cache-cleanup.min-age` = `24h`
- added: `app.ister.server.continue-watching.history-days` = `150`
- added: `app.ister.server.continue-watching.rebuild-cron` = `0 30 3 * * *`
- added: `app.ister.server.continue-watching.rebuild.enabled` = `true`
- added: `app.ister.server.image-thumbnail.max-idle` = `30d`
- added: `app.ister.server.segment-detect.chunk-size` = `4`
- added: `app.ister.transcoder.hls.max-concurrent-files` = `2`
- added: `app.ister.upload.chunk-size` = `16MB`
- added: `app.ister.upload.cleanup-interval` = `PT1H`
- added: `app.ister.upload.enabled` = `true`
- added: `app.ister.upload.max-active-sessions` = `2`
- added: `app.ister.upload.max-concurrent-chunks` = `4`
- added: `app.ister.upload.max-files-per-session` = `20000`
- added: `app.ister.upload.min-free-space` = `5GB`
- added: `app.ister.upload.session-idle-timeout` = `24h`
- added: `logging.level.com.github.kokorin.jaffree.ffmpeg.FFmpeg` = `ERROR`
- added: `logging.level.com.github.kokorin.jaffree.process.BaseStdReader` = `ERROR`
- added: `management.endpoints.web.exposure.include` = `health,metrics,prometheus`
- added: `spring.datasource.hikari.connection-timeout` = `10000`
- added: `spring.datasource.hikari.maximum-pool-size` = `20`
- added: `spring.graphql.graphiql.enabled` = `true`
- added: `spring.graphql.websocket.connection-init-timeout` = `30s`
- added: `spring.graphql.websocket.keep-alive` = `25s`
- added: `spring.jpa.properties.hibernate.default_batch_fetch_size` = `50`
- added: `spring.jpa.show-sql` = `false`
- added: `spring.rabbitmq.listener.simple.concurrency` = `3`
- added: `spring.rabbitmq.listener.simple.prefetch` = `1`
- added: `spring.rabbitmq.listener.simple.retry.enabled` = `true`
- added: `spring.rabbitmq.listener.simple.retry.initial-interval` = `2s`
- added: `spring.rabbitmq.listener.simple.retry.max-attempts` = `3`
- added: `spring.rabbitmq.listener.simple.retry.multiplier` = `2`
- added: `springdoc.swagger-ui.oauth.clientId` = `ister`

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 2.0.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.4.2...v2.0.0

## ister-chart v1.4.2

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.2.1 |
| website | `ghcr.io/ister-app/player` | 2.14.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.2.1 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/player docker tag to v2.14.0 ([`b69962e`](https://github.com/ister-app/chart/commit/b69962e))
- chore(deps): update ghcr.io/ister-app/server docker tag to v5.2.1 ([`404ebeb`](https://github.com/ister-app/chart/commit/404ebeb))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.4.2
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.4.1...v1.4.2

## ister-chart v1.4.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.2.0 |
| website | `ghcr.io/ister-app/player` | 2.13.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.2.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/player docker tag to v2.13.0 ([`3add3c2`](https://github.com/ister-app/chart/commit/3add3c2))
- chore(deps): update renovatebot/github-action action to v46.3.7 ([`e0bf81e`](https://github.com/ister-app/chart/commit/e0bf81e))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.4.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.4.0...v1.4.1

## ister-chart v1.4.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.2.0 |
| website | `ghcr.io/ister-app/player` | 2.12.1 |
| migrations | `ghcr.io/ister-app/migrations` | 5.2.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Features

- feat(server): optional OIDC audience value and Keycloak checklist ([`f201bec`](https://github.com/ister-app/chart/commit/f201bec))

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v5.2.0 ([`838d7f2`](https://github.com/ister-app/chart/commit/838d7f2))
- chore(deps): update ghcr.io/ister-app/player docker tag to v2.12.1 ([`1a782ac`](https://github.com/ister-app/chart/commit/1a782ac))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.4.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.3.6...v1.4.0

## ister-chart v1.3.6

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.1.1 |
| website | `ghcr.io/ister-app/player` | 2.12.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.1.1 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/player docker tag to v2.12.0 ([`b059728`](https://github.com/ister-app/chart/commit/b059728))
- chore(deps): update renovatebot/github-action action to v46.3.6 ([`6d4ecb2`](https://github.com/ister-app/chart/commit/6d4ecb2))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.3.6
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.3.5...v1.3.6

## ister-chart v1.3.5

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.1.1 |
| website | `ghcr.io/ister-app/player` | 2.11.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.1.1 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v5.1.1 ([`5202626`](https://github.com/ister-app/chart/commit/5202626))
- chore(deps): update renovatebot/github-action action to v46.3.5 ([`3fd8033`](https://github.com/ister-app/chart/commit/3fd8033))
- chore(deps): update renovatebot/github-action action to v46.3.4 ([`4a0930a`](https://github.com/ister-app/chart/commit/4a0930a))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.3.5
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.3.4...v1.3.5

## ister-chart v1.3.4

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.1.0 |
| website | `ghcr.io/ister-app/player` | 2.11.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.1.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v5.1.0 ([`37828ab`](https://github.com/ister-app/chart/commit/37828ab))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.3.4
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.3.3...v1.3.4

## ister-chart v1.3.3

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.0.1 |
| website | `ghcr.io/ister-app/player` | 2.11.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.0.1 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/player docker tag to v2.11.0 ([`ae4df03`](https://github.com/ister-app/chart/commit/ae4df03))
- chore(deps): update ghcr.io/ister-app/server docker tag to v5.0.1 ([`f236b2a`](https://github.com/ister-app/chart/commit/f236b2a))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.3.3
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.3.2...v1.3.3

## ister-chart v1.3.2

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 5.0.0 |
| website | `ghcr.io/ister-app/player` | 2.10.0 |
| migrations | `ghcr.io/ister-app/migrations` | 5.0.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v5 ([`2665288`](https://github.com/ister-app/chart/commit/2665288))
- chore(deps): update ghcr.io/ister-app/player docker tag to v2.10.0 ([`db7b1c7`](https://github.com/ister-app/chart/commit/db7b1c7))
- chore(deps): update renovatebot/github-action action to v46.3.3 ([`6036967`](https://github.com/ister-app/chart/commit/6036967))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.3.2
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.3.1...v1.3.2

## ister-chart v1.3.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 4.2.1 |
| website | `ghcr.io/ister-app/player` | 2.9.0 |
| migrations | `ghcr.io/ister-app/migrations` | 4.2.1 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v4.2.1 ([`1339058`](https://github.com/ister-app/chart/commit/1339058))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.3.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.3.0...v1.3.1

## ister-chart v1.3.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 4.2.0 |
| website | `ghcr.io/ister-app/player` | 2.9.0 |
| migrations | `ghcr.io/ister-app/migrations` | 4.2.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Features

- feat: startup probes for Typesense and the internal database ([`70114a5`](https://github.com/ister-app/chart/commit/70114a5))

### Other

- docs: how to change the IP family of an existing Service ([`ed2ec11`](https://github.com/ister-app/chart/commit/ed2ec11))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.3.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.2.3...v1.3.0

## ister-chart v1.2.3

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 4.2.0 |
| website | `ghcr.io/ister-app/player` | 2.9.0 |
| migrations | `ghcr.io/ister-app/migrations` | 4.2.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.6-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v4.2.0 ([`ad67f83`](https://github.com/ister-app/chart/commit/ad67f83))
- chore(deps): update ghcr.io/ister-app/player docker tag to v2.9.0 ([`a0c157d`](https://github.com/ister-app/chart/commit/a0c157d))
- chore(deps): update ghcr.io/ister-app/server docker tag to v4.1.0 ([`4245008`](https://github.com/ister-app/chart/commit/4245008))
- chore(deps): update rabbitmq docker tag to v4.3.6 ([`ef68316`](https://github.com/ister-app/chart/commit/ef68316))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.2.3
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.2.2...v1.2.3

## ister-chart v1.2.2

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 4.0.0 |
| website | `ghcr.io/ister-app/player` | 2.8.1 |
| migrations | `ghcr.io/ister-app/migrations` | 4.0.0 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.5-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v4 ([`56542db`](https://github.com/ister-app/chart/commit/56542db))
- chore(deps): update renovatebot/github-action action to v46.3.1 ([`28003f9`](https://github.com/ister-app/chart/commit/28003f9))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.2.2
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.2.1...v1.2.2

## ister-chart v1.2.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 3.5.2 |
| website | `ghcr.io/ister-app/player` | 2.8.1 |
| migrations | `ghcr.io/ister-app/migrations` | 3.5.2 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.5-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/player docker tag to v2.8.1 ([`4d42bec`](https://github.com/ister-app/chart/commit/4d42bec))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.2.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.2.0...v1.2.1

## ister-chart v1.2.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 3.5.2 |
| website | `ghcr.io/ister-app/player` | 2.8.0 |
| migrations | `ghcr.io/ister-app/migrations` | 3.5.2 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.5-management-alpine |

### Features

- feat(workloads): revisionHistoryLimit on every workload the chart ships ([`2f40c7e`](https://github.com/ister-app/chart/commit/2f40c7e))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.2.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.1.2...v1.2.0

## ister-chart v1.1.2

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 3.5.2 |
| website | `ghcr.io/ister-app/player` | 2.8.0 |
| migrations | `ghcr.io/ister-app/migrations` | 3.5.2 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.5-management-alpine |

### Fixes

- fix(ci): stop Renovate opening a dependency dashboard on every pass ([`57ca7b3`](https://github.com/ister-app/chart/commit/57ca7b3))
- fix(ci): wait for the ingress-nginx webhook, not just for the pod ([`e5dae0b`](https://github.com/ister-app/chart/commit/e5dae0b))

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v3.5.2 ([`2a428f0`](https://github.com/ister-app/chart/commit/2a428f0))
- chore(deps): update renovatebot/github-action action to v46.3.0 ([`40088c3`](https://github.com/ister-app/chart/commit/40088c3))

### Other

- chore(ci): let Renovate track ci.yml's helm pin too ([`e3dbfe6`](https://github.com/ister-app/chart/commit/e3dbfe6))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.1.2
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.1.1...v1.1.2

## ister-chart v1.1.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 3.5.1 |
| website | `ghcr.io/ister-app/player` | 2.8.0 |
| migrations | `ghcr.io/ister-app/migrations` | 3.5.1 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.5-management-alpine |

### Dependency updates

- chore(deps): update dependency helm to v3.22.0 ([`6a3ac0c`](https://github.com/ister-app/chart/commit/6a3ac0c))

### Other

- docs: describe what the chart does, not which version started doing it ([`d083985`](https://github.com/ister-app/chart/commit/d083985))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.1.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.1.0...v1.1.1

## ister-chart v1.1.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 3.5.1 |
| website | `ghcr.io/ister-app/player` | 2.8.0 |
| migrations | `ghcr.io/ister-app/migrations` | 3.5.1 |
| database | `postgres` | 18.6 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.3.5-management-alpine |

### Features

- feat(typesense): listen dual-stack by default, so an IPv6-only cluster works ([`3ea8c1e`](https://github.com/ister-app/chart/commit/3ea8c1e))
- feat: values for three things the chart could not express ([`a378274`](https://github.com/ister-app/chart/commit/a378274))

### Fixes

- fix(secrets): no TMDB key needed when tmdbApiUrl points elsewhere ([`3bd44f3`](https://github.com/ister-app/chart/commit/3bd44f3))
- fix(hwaccel): privileged rendered a securityContext the API server rejects ([`c75bdf8`](https://github.com/ister-app/chart/commit/c75bdf8))
- fix(website): probe nginx over 127.0.0.1, not over the pod IP ([`6251769`](https://github.com/ister-app/chart/commit/6251769))

### Dependency updates

- fix(deps): player 2.8.0, which closes the last IPv6-only gap ([`be428e5`](https://github.com/ister-app/chart/commit/be428e5))
- fix(deps): pin postgres to 18.6 instead of the floating major tag ([`37a45ba`](https://github.com/ister-app/chart/commit/37a45ba))
- fix(deps): mock-oauth2-server 6.0.2 and python 3.14-alpine (CI only) ([`09c5434`](https://github.com/ister-app/chart/commit/09c5434))
- fix(deps): rabbitmq 4.2.5 -> 4.3.5-management-alpine, curl 8.21.0 -> 8.22.0 ([`4220f55`](https://github.com/ister-app/chart/commit/4220f55))

### Other

- docs: identity provider chapter, the GitOps caveat and the demo recipe ([`b7c414f`](https://github.com/ister-app/chart/commit/b7c414f))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.1.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.0.1...v1.1.0

## ister-chart v1.0.1

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 3.5.1 |
| website | `ghcr.io/ister-app/player` | 2.8.0 |
| migrations | `ghcr.io/ister-app/migrations` | 3.5.1 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.2.5-management-alpine |

### Dependency updates

- chore(deps): update ghcr.io/ister-app/player docker tag to v2.8.0 ([`30c600b`](https://github.com/ister-app/chart/commit/30c600b))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.0.1
```

**Full changelog**: https://github.com/ister-app/chart/compare/v1.0.0...v1.0.1

## ister-chart v1.0.0

| Component | Image | Version |
|---|---|---|
| server | `ghcr.io/ister-app/server` | 3.5.1 |
| website | `ghcr.io/ister-app/player` | 2.7.1 |
| migrations | `ghcr.io/ister-app/migrations` | 3.5.1 |
| database | `postgres` | 18 |
| typesense | `docker.io/typesense/typesense` | 30.2 |
| rabbitmq | `rabbitmq` | 4.2.5-management-alpine |

### Breaking changes

- feat!: bundle RabbitMQ as the chart's own StatefulSet instead of the Bitnami subchart ([`69c59d2`](https://github.com/ister-app/chart/commit/69c59d2))

### Features

- feat: NetworkPolicy template and Pod Security notes ([`d78769d`](https://github.com/ister-app/chart/commit/d78769d))
- feat: helper-node pods, hardware encoding, external service URLs and pod escape hatches ([`40bdcbb`](https://github.com/ister-app/chart/commit/40bdcbb))
- feat: controller-neutral exposure — Gateway API route, ingress presets, service knobs ([`03db8c0`](https://github.com/ister-app/chart/commit/03db8c0))

### Fixes

- fix: external typesense secret, broker/search ports, flyway tag and a strict schema ([`6f4597e`](https://github.com/ister-app/chart/commit/6f4597e))

### Dependency updates

- chore(deps): update ghcr.io/ister-app/server docker tag to v3.5.1 ([`b637d42`](https://github.com/ister-app/chart/commit/b637d42))
- chore(deps): update ghcr.io/ister-app/server docker tag to v3.5.0 ([`6484f0b`](https://github.com/ister-app/chart/commit/6484f0b))
- chore(deps): update renovatebot/github-action action to v46.2.6 ([`fbddc22`](https://github.com/ister-app/chart/commit/fbddc22))

### Other

- ci: pick e2e fixtures by what they need, and stub the TMDB extras ([`d0fc5fa`](https://github.com/ister-app/chart/commit/d0fc5fa))
- ci: poll the master playlist in the streaming scenario, ClusterIP Envoy on kind ([`dc29f83`](https://github.com/ister-app/chart/commit/dc29f83))
- ci: exercise ingress-nginx and Envoy Gateway, an older Kubernetes, and the upgrade path ([`c0f3f08`](https://github.com/ister-app/chart/commit/c0f3f08))

### Install

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister --version 1.0.0
```

**Full changelog**: https://github.com/ister-app/chart/compare/v0.5.1...v1.0.0

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

