---
description: Installeer de zelfgehoste Ister-mediaserver op Kubernetes met Helm, inclusief meegeleverde PostgreSQL, RabbitMQ en Typesense of je eigen diensten.
---

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
| RabbitMQ | De message broker (officiële image, één node) | ja (`rabbitmq.enabled: true`) |
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

`true` installeert een RabbitMQ-StatefulSet met één node op de officiële `rabbitmq`-image
(ister gebruikt de broker alleen voor doorstroomwerk, dus clustering is niet nodig); het
wachtwoord en de Erlang-cookie worden eenmalig gegenereerd, of komen uit
`rabbitmq.auth.existingSecret` (sleutels `rabbitmq-password`, `rabbitmq-erlang-cookie`).
`false` gebruikt het blok `externalRabbitmq` — diens `existingSecret` heeft de sleutel
`rabbitmq-password` nodig.

Upgraden vanaf een chart van vóór 1.0, die de Bitnami-subchart meeleverde: de oude
StatefulSet, Service en PVC met de naam `<release>-rabbitmq` worden niet overgenomen.
Verwijder ze vóór de upgrade (de queues bevatten alleen doorstroomwerk), of draai de
upgrade en verwijder daarna de achtergebleven PVC; de server verbindt zelf opnieuw met de
nieuwe broker.

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

## Naar buiten: Ingress of Gateway API

Beide publiceren de player op `/` en de API op `server.contextPath` (standaard `/api`)
op één hostnaam; kies er één.

- **Ingress** — `ingress.enabled: true` met `ingress.host`. `ingress.className` is
  standaard leeg (de default IngressClass van het cluster); zet hem als je meerdere
  controllers draait. TLS via cert-manager wanneer `ingress.tls.certIssuer` is gezet.
- **Gateway API** — `gateway.enabled: true` met `gateway.hostnames` en
  `gateway.parentRefs` (de Gateway en listener om aan te hangen; de Gateway zelf is van
  jou en moet routes uit de namespace van de chart toelaten). Werkt met Envoy Gateway,
  Cilium, Istio, de Gateway-provider van Traefik en dergelijke.

Wat er ook vóór ister staat, het moet drie dingen toelaten die de meeste proxies
standaard begrenzen: onbegrensde request-bodies (helper-nodes uploaden hele HLS-segmenten
en ondertitelbestanden), responses die minuten tot uren lopen (HLS-afspelen, een
helper-node die een bron van meerdere GB leest) en websocket-upgrades op
`/api/graphql`. `ingress.controller` (`nginx` | `traefik` | `haproxy`) rendert de
bijbehorende annotaties uit `ingress.proxy`; de HTTPRoute zet `timeouts.request: 0s` op de
`/api`-regel (`gateway.apiTimeouts`). Traefik heeft per Ingress niets nodig, maar zijn
leestimeouts zijn entrypoint-instellingen
(`entryPoints.<naam>.transport.respondingTimeouts`).

`/.well-known/ister`, het document dat clients als eerste ophalen (naam van de
instantie, OIDC-issuer, API-URL), wordt door de website-pod zelf geserveerd
(`website.wellKnown`, standaard aan), dus het werkt achter elke controller, een NodePort
of een port-forward. De oudere ingress-nginx-snippet (`ingress.wellKnown`) bestaat nog
voor opstellingen die erop leunen.

De Services kennen de gebruikelijke knoppen (`server.service`, `website.service`,
`typesense.service`: `type`, `nodePort`, `annotations`, `loadBalancerIP`, `ipFamilies`,
...). Geef op een IPv6-first cluster de website- en Typesense-Services
`ipFamilyPolicy: SingleStack` / `ipFamilies: [IPv4]` tenzij de player-image 2.8 of nieuwer
is: oudere images luisteren alleen op IPv4, en een IPv6-only ClusterIP antwoordt dan 503.

## Helper-nodes en hardware-encoding

Een tweede server-pod kan het CPU-zware werk — HLS-transcoderen, intro-/outro-detectie,
ondertitel-extractie en OCR — voor de directories van de hoofdserver overnemen zonder zelf
media te bezitten: hij leest de bron via HTTP van de hoofdserver en uploadt het resultaat
terug. Declareer ze onder `helpers`, één regel per pod, elk met de directories van de
hoofdserver (`mediaVolumes[].name`) waarmee hij helpt en optioneel welke jobfamilies; de
hoofdserver kan families volledig uit handen geven met `server.helper.offloadJobs`. Zet
`server.clusterName` zodat alle pods zich als één cluster aan clients presenteren. De
helpers delen de database, broker en zoekindex van de chart en hebben verder niets nodig.
Zie de serverdocumentatie, hoofdstuk Multi-node, voor hoe het werk wordt verdeeld.

Hardware-encoding is `hwaccel` op de hoofdserver en op elke helper: `type: vaapi`
(Intel/AMD) of `nvdec` (NVIDIA), plus een manier om de pod de GPU te geven. Gebruik bij
voorkeur een device-plugin (`hwaccel.resources`, bijvoorbeeld `gpu.intel.com/i915: 1`,
`amd.com/gpu: 1`, `nvidia.com/gpu: 1`, of `squat.ai/dri: 1` met de generic device plugin)
— zonder privileges en planbaar. `hwaccel.hostPath: true` mount in plaats daarvan het
devicebestand van de node, wat de device-cgroup alleen toestaat voor een privileged
container (`hwaccel.privileged`). Zet de group-id's van `video`/`render` van de node in
`hwaccel.supplementalGroups` als het device group-eigendom is.

## Netwerkbeleid en podbeveiliging

`networkPolicy.enabled: true` rendert NetworkPolicies voor alleen inkomend verkeer: de
datastores accepteren alleen verkeer van de pods van deze release, de server, helpers en
website ook van `networkPolicy.ingressFrom` — zet daar de namespace van je ingress-controller
of Gateway in, en Prometheus voor de monitorpoort. Uitgaand verkeer blijft open
(metadatabronnen, podcastfeeds, je OIDC-issuer). De pods voldoen aan de Pod Security
Standard "restricted"; zet op OpenShift `runAsUser`/`fsGroup` op `null` in de
`podSecurityContext`-blokken zodat de SCC de UID toewijst.

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
