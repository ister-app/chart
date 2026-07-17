# Ister installeren met Helm

Dit hoofdstuk legt uit hoe de ister Helm chart werkt en hoe je hem installeert. De chart
zet de volledige ister-mediaserver neer: de API-server, de webplayer, en — tenzij je je
eigen diensten meebrengt — PostgreSQL, RabbitMQ en Typesense.

## Wat de chart installeert

| Component | Wat het is | Standaard meegeleverd? |
|---|---|---|
| server | De Spring Boot-backend (`ghcr.io/ister-app/server`) | altijd |
| website | De webplayer (`ghcr.io/ister-app/player`) | altijd |
| PostgreSQL | De database | ja (`database.mode: internal`) |
| RabbitMQ | De message broker (Bitnami-subchart) | ja (`rabbitmq.enabled: true`) |
| Typesense | De zoekmachine | ja (`typesense.enabled: true`) |
| Flyway | Databasemigraties (`ghcr.io/ister-app/migrations`) | draait als init-container |

De standaardwaarden leveren een op zichzelf staande ister zonder ingress en zonder
mediavolumes — genoeg om het te proberen, geen productie-opstelling.

## Vereisten

- Een Kubernetes-cluster en Helm 3.
- Een [TMDB API-key](https://www.themoviedb.org/settings/api) voor film-/seriemetadata.
- Een OIDC-issuer (bijvoorbeeld Keycloak) — ister beheert zelf geen gebruikers.
- Voor `database.mode: cnpg`: de [CloudNativePG](https://cloudnative-pg.io/)-operator.
- Voor ingress met TLS: een ingress-controller en optioneel cert-manager.

## Installeren

De chart wordt gepubliceerd als OCI-artifact:

```sh
helm install ister oci://ghcr.io/ister-app/charts/ister \
  --namespace ister --create-namespace \
  --set server.tmdbApiKey=<jouw-key> \
  --set server.oidc.url=https://keycloak.example.com/realms/auth
```

Voor alles voorbij een eerste test: begin met `values-production.example.yaml` uit de
[chart-repository](https://github.com/ister-app/chart) en installeer met `-f`. Pin een
chartversie met `--version`; bij elke chartversie hoort een GitHub Release waarvan de
release notes de exact meegeleverde image-versies vermelden.

## Gebundelde of externe datastores

Alles waar de server op leunt kan óf door de chart worden uitgerold, óf naar een
bestaande dienst wijzen. Wat je ook kiest, de onderliggende templates merken het verschil
nooit — dat is de centrale ontwerpregel van de chart.

### PostgreSQL — `database.mode`

- `internal` — één postgres-Deployment + PVC. Alleen voor ontwikkeling: één instantie,
  geen back-ups.
- `cnpg` — een CloudNativePG-`Cluster` (standaard 3 instanties, anti-affinity, optionele
  Barman Cloud-back-ups naar S3 onder `database.cnpg.backup`). Vereist de CNPG-operator.
- `external` — een bestaande PostgreSQL, geconfigureerd onder `database.external`.

Alle drie de modi komen uit op **één Secret met de sleutels `host`, `port`, `dbname`,
`user`, `password`** — de vorm die CNPG genereert voor zijn `<cluster>-app`-Secret; de
andere twee modi schrijven diezelfde vorm zelf. Breng je een eigen Secret mee
(`existingSecret`), dan moet die exact deze sleutels hebben; het `<cluster>-app`-Secret
van een buiten deze chart beheerd CNPG-cluster voldoet al.

### RabbitMQ — `rabbitmq.enabled`

`true` installeert de Bitnami RabbitMQ-subchart (alles onder `rabbitmq:` gaat één-op-één
naar die chart). `false` gebruikt het blok `externalRabbitmq` — diens `existingSecret`
heeft de sleutel `rabbitmq-password` nodig.

### Typesense — `typesense.enabled`

`true` installeert Typesense met een eigen PVC. `false` gebruikt `typesense.external` —
diens `existingSecret` heeft de sleutel `api-key` nodig.

## Secrets en wachtwoorden

- **Niets geheims hoort in een values-bestand.** Elke credential heeft een
  `existingSecret`-ontsnappingsluik; gebruik dat (of een secret manager) overal waar het
  ertoe doet.
- **Gegenereerde wachtwoorden overleven upgrades.** Laat je de chart een wachtwoord
  genereren, dan zoekt hij bij een upgrade het live Secret op en behoudt de bestaande
  waarde — anders zou elke `helm upgrade` de server buiten zijn eigen database sluiten.
  Daarom verschilt de uitvoer van `helm template` ook van wat `helm install`
  daadwerkelijk toepast.
- **Een Secret roteren herstart de server.** Alle credentials worden gehasht in een
  `checksum/secrets`-podannotatie, dus een gewijzigd Secret rolt de Deployment.

## Databasemigraties

Flyway draait als **init-container op de server-pod** (voorafgegaan door een
`wait-for-db`-container), zodat de server nooit tegen een ongemigreerd schema kan
starten. Het is bewust geen Helm-hook: met een gebundelde database zou een
pre-install-hook wachten op een database die Helm nog niet heeft aangemaakt. De
migrations-image publiceert dezelfde versie als de server, dus `flyway.image.tag` blijft
leeg en volgt de serverversie automatisch.

## Mediabibliotheken en -volumes

Twee value-lijsten verbinden de server met je media:

- `server.libraries` — de bibliotheken die ister scant; elk met een `name` en een `type`
  (`SHOW`, `MOVIE`, `MUSIC`, `BOOK`, `PODCAST`, `COMIC`).
- `server.mediaVolumes` — de volumes die in de server-pod worden gemount, elk gedragen
  door precies één van `hostPath`, `existingClaim` of `nfs`, en via `library` gekoppeld
  aan een bibliotheek (laat dat weg voor alleen een mount). **Geen slash aan het eind van
  `mountPath`** — de scanner slaat de boom dan over.

Twee andere opslagknoppen doen ertoe:

- `cache` — een PVC voor de cachemap van de server (transcodes, afbeeldingen). Standaard
  `ReadWriteOnce`, en daarom moet `server.replicaCount` op 1 blijven — de chart weigert
  meer replica's te renderen tenzij je overschakelt op `ReadWriteMany`.
- `server.tmp` — kladruimte voor transcoderen. Zet dit uit wanneer `mountPath` binnen een
  van je mediavolumes valt, anders overschaduwt het aparte volume dat pad.

## Ingress

`ingress.enabled: true` publiceert de player op `/` en de API op `server.contextPath`
(standaard `/api`) op `ingress.host`, met TLS via cert-manager wanneer
`ingress.tls.certIssuer` is gezet. `ingress.wellKnown.enabled` serveert daarnaast
`/.well-known/ister` voor client-discovery — geïmplementeerd als een
ingress-nginx-server-snippet, dat moderne ingress-nginx standaard uitschakelt
(`allow-snippet-annotations`); zet dat eerst aan op de controller.

## Beheer

- **Upgrades**: `helm upgrade ister oci://ghcr.io/ister-app/charts/ister --version <v>`
  met je values-bestand. Gegenereerde wachtwoorden blijven behouden (zie hierboven).
- **Rooktest**: `helm test ister -n ister --logs` draait de meegeleverde
  connectiviteitstest.
- **Monitoring**: `monitoring.enabled` rendert een Prometheus Operator-ServiceMonitor
  voor de actuator van de server; in `cnpg`-modus dekt `database.cnpg.podMonitor` de
  database.
- **Verwijderen**: de PVC's van database, cache en Typesense blijven standaard staan
  (`retain: true`), dus een uninstall is niet destructief; zet `retain: false` waar je
  ze met de release opgeruimd wilt hebben.

## Values-referentie

Elke value die de chart accepteert, met zijn standaardwaarde. Deze tabel wordt
gegenereerd uit de `values.yaml` van de release waarmee deze documentatie is
meegeleverd; `values.schema.json` dwingt hetzelfde contract af bij elke render.

<!-- VALUES:BEGIN (generated by ci/build-docs.sh — do not edit between the markers) -->
<!-- VALUES:END -->
