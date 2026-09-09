{{/*
Expand the name of the chart.
*/}}
{{- define "ister.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ister.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "ister.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels. Must stay stable across upgrades — never add version/chart here.
Usage: {{ include "ister.selectorLabels" (dict "ctx" . "component" "server") }}
*/}}
{{- define "ister.selectorLabels" -}}
{{- $ctx := .ctx -}}
app.kubernetes.io/name: {{ include "ister.name" $ctx }}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}
{{- with .component }}
app.kubernetes.io/component: {{ . }}
{{- end }}
{{- end }}

{{/*
Common labels.
Usage: {{ include "ister.labels" (dict "ctx" . "component" "server") }}
*/}}
{{- define "ister.labels" -}}
{{- $ctx := .ctx -}}
helm.sh/chart: {{ include "ister.chart" $ctx }}
{{ include "ister.selectorLabels" . }}
{{- if $ctx.Chart.AppVersion }}
app.kubernetes.io/version: {{ $ctx.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service }}
{{- with $ctx.Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Render an image reference from a {repository, tag, digest, pullPolicy} map.
Falls back to .Chart.AppVersion when tag is empty, so a chart release pins its app version.
Usage: {{ include "ister.image" (dict "ctx" . "image" .Values.server.image) }}
*/}}
{{- define "ister.image" -}}
{{- $img := .image -}}
{{- $registry := .ctx.Values.global.imageRegistry -}}
{{- $repo := ternary (printf "%s/%s" (trimSuffix "/" $registry) $img.repository) $img.repository (ne $registry "") -}}
{{- if $img.digest -}}
{{- printf "%s@%s" $repo $img.digest -}}
{{- else -}}
{{- printf "%s:%s" $repo (default .ctx.Chart.AppVersion $img.tag) -}}
{{- end -}}
{{- end }}

{{- define "ister.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ister.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end }}

{{/*
================= Database =================
All three modes expose the same Secret keys (host, port, dbname, user, password),
so the server and the Flyway job never branch on database.mode.
CNPG generates <cluster>-app with exactly these keys, which is why the internal
mode's hand-written Secret mirrors them.
*/}}

{{- define "ister.cnpgClusterName" -}}
{{- printf "%s-database" (include "ister.fullname" .) -}}
{{- end }}

{{- define "ister.databaseSecretName" -}}
{{- if eq .Values.database.mode "external" -}}
{{- default (printf "%s-database-app" (include "ister.fullname" .)) .Values.database.external.existingSecret -}}
{{- else if eq .Values.database.mode "cnpg" -}}
{{- printf "%s-app" (include "ister.cnpgClusterName" .) -}}
{{- else -}}
{{- printf "%s-database-app" (include "ister.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
================= RabbitMQ =================
Bundled: the chart's own StatefulSet + Secret. External: externalRabbitmq.* and either
its existingSecret or the Secret the chart renders from externalRabbitmq.password.
*/}}

{{- define "ister.rabbitmqHost" -}}
{{- if .Values.rabbitmq.enabled -}}
{{- printf "%s-rabbitmq" (include "ister.fullname" .) -}}
{{- else -}}
{{- required "externalRabbitmq.host is required when rabbitmq.enabled is false" .Values.externalRabbitmq.host -}}
{{- end -}}
{{- end }}

{{- define "ister.rabbitmqPort" -}}
{{- if .Values.rabbitmq.enabled -}}5672{{- else -}}{{ .Values.externalRabbitmq.port }}{{- end -}}
{{- end }}

{{- define "ister.rabbitmqUser" -}}
{{- if .Values.rabbitmq.enabled -}}
{{- .Values.rabbitmq.auth.username -}}
{{- else -}}
{{- .Values.externalRabbitmq.user -}}
{{- end -}}
{{- end }}

{{- define "ister.rabbitmqSecretName" -}}
{{- if .Values.rabbitmq.enabled -}}
{{- default (printf "%s-rabbitmq" (include "ister.fullname" .)) .Values.rabbitmq.auth.existingSecret -}}
{{- else -}}
{{- default (printf "%s-rabbitmq" (include "ister.fullname" .)) .Values.externalRabbitmq.existingSecret -}}
{{- end -}}
{{- end }}

{{/* Both the bundled and the external Secret use this key. */}}
{{- define "ister.rabbitmqSecretKey" -}}rabbitmq-password{{- end }}

{{/*
================= Typesense =================
*/}}

{{- define "ister.typesenseHost" -}}
{{- if .Values.typesense.enabled -}}
{{- printf "%s-typesense" (include "ister.fullname" .) -}}
{{- else -}}
{{- .Values.typesense.external.host -}}
{{- end -}}
{{- end }}

{{- define "ister.typesenseSecretName" -}}
{{- if .Values.typesense.enabled -}}
{{- default (printf "%s-typesense" (include "ister.fullname" .)) .Values.typesense.existingSecret -}}
{{- else -}}
{{- default (printf "%s-typesense" (include "ister.fullname" .)) .Values.typesense.external.existingSecret -}}
{{- end -}}
{{- end }}

{{/*
================= Server secret (TMDB) =================
*/}}
{{- define "ister.serverSecretName" -}}
{{- default (printf "%s-server" (include "ister.fullname" .)) .Values.server.existingSecret -}}
{{- end }}

{{/*
The external base URL the browser uses to reach the API. Derived from the ingress
host so it cannot drift from the Ingress and the /.well-known/ister document.
*/}}
{{- define "ister.serverUrl" -}}
{{- if .Values.server.url -}}
{{- .Values.server.url -}}
{{- else if .Values.ingress.enabled -}}
{{- $scheme := ternary "https" "http" .Values.ingress.tls.enabled -}}
{{- printf "%s://%s%s" $scheme (required "ingress.host is required when ingress.enabled is true" .Values.ingress.host) .Values.server.contextPath -}}
{{- else if .Values.gateway.enabled -}}
{{- $scheme := ternary "https" "http" .Values.gateway.tls -}}
{{- printf "%s://%s%s" $scheme (required "gateway.hostnames needs at least one entry when gateway.enabled is true" (first .Values.gateway.hostnames)) .Values.server.contextPath -}}
{{- else -}}
{{- printf "http://localhost:8080%s" .Values.server.contextPath -}}
{{- end -}}
{{- end }}

{{/*
The /.well-known/ister discovery document: instance name, OIDC discovery URL, API base.
Built from the same values as OIDC_URL and APP_ISTER_SERVER_URL, so the three cannot drift.
*/}}
{{- define "ister.wellKnownDocument" -}}
{{ .Values.server.name }}
{{ required "server.oidc.url is required" .Values.server.oidc.url }}/.well-known/openid-configuration
{{ include "ister.serverUrl" . }}
{{- end }}

{{/*
Ingress annotations for the controller preset in ingress.controller. Values from
ingress.annotations are merged on top and win.
*/}}
{{- define "ister.ingressPresetAnnotations" -}}
{{- $p := .Values.ingress.proxy -}}
{{- $timeout := $p.timeoutSeconds | toString -}}
{{- if eq .Values.ingress.controller "nginx" -}}
nginx.ingress.kubernetes.io/proxy-body-size: {{ ternary "0" (printf "%sm" ($p.bodySize | toString)) (eq ($p.bodySize | toString) "0") | quote }}
nginx.ingress.kubernetes.io/proxy-read-timeout: {{ $timeout | quote }}
nginx.ingress.kubernetes.io/proxy-send-timeout: {{ $timeout | quote }}
nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
{{- else if eq .Values.ingress.controller "haproxy" -}}
haproxy.org/timeout-server: {{ printf "%ss" $timeout | quote }}
haproxy.org/timeout-tunnel: {{ printf "%ss" $timeout | quote }}
{{- else if eq .Values.ingress.controller "traefik" -}}
{{- /* No per-Ingress knobs: Traefik has no body limit by default and its read timeouts
       are entrypoint settings. Nothing to render. */ -}}
{{- else if .Values.ingress.controller -}}
{{- fail (printf "ingress.controller %q is not one of: nginx, traefik, haproxy" .Values.ingress.controller) -}}
{{- end -}}
{{- end }}

{{/*
Common Service spec fields from a {type, port, nodePort, loadBalancerIP, ...} map.
Usage: {{ include "ister.serviceSpec" .Values.server.service | nindent 2 }}
*/}}
{{- define "ister.serviceSpec" -}}
{{- with .type }}
type: {{ . }}
{{- end }}
{{- with .loadBalancerIP }}
loadBalancerIP: {{ . }}
{{- end }}
{{- with .loadBalancerClass }}
loadBalancerClass: {{ . }}
{{- end }}
{{- with .externalTrafficPolicy }}
externalTrafficPolicy: {{ . }}
{{- end }}
{{- with .ipFamilyPolicy }}
ipFamilyPolicy: {{ . }}
{{- end }}
{{- with .ipFamilies }}
ipFamilies:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
================= Server pods (main and helpers) =================
The env every server pod shares: database, broker, search, OIDC, TMDB, cluster identity,
external service URLs. Libraries/directories/helper settings are per pod and rendered by
the caller. Usage: {{ include "ister.serverCommonEnv" . | nindent 12 }}
*/}}
{{- define "ister.serverCommonEnv" -}}
{{- $secret := include "ister.databaseSecretName" . }}
# --- Database. Note DB_PATH, not DB_PORT: that is what core.properties
# --- interpolates into the JDBC URL. Flyway reads DB_PORT instead.
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: host
- name: DB_PATH
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: port
- name: DB_NAME
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: dbname
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: user
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secret }}
      key: password
# --- Application
- name: SERVER_SERVLET_CONTEXT_PATH
  value: {{ .Values.server.contextPath | quote }}
- name: APP_ISTER_CLUSTER_NAME
  value: {{ default .Values.server.name .Values.server.clusterName | quote }}
- name: OIDC_URL
  value: {{ required "server.oidc.url is required" .Values.server.oidc.url | quote }}
- name: APP_ISTER_SERVER_TMDB_APIKEY
  valueFrom:
    secretKeyRef:
      name: {{ include "ister.serverSecretName" . }}
      key: tmdb-api-key
{{- with .Values.server.languages }}
- name: ISTER_LANGUAGES
  value: {{ . | quote }}
{{- end }}
{{- with .Values.server.websocketAllowedOrigins }}
- name: APP_ISTER_SERVER_WEBSOCKET_ALLOWED_ORIGINS
  value: {{ . | quote }}
{{- end }}
# --- RabbitMQ
- name: SPRING_RABBITMQ_HOST
  value: {{ include "ister.rabbitmqHost" . | quote }}
- name: SPRING_RABBITMQ_PORT
  value: {{ include "ister.rabbitmqPort" . | quote }}
- name: SPRING_RABBITMQ_USERNAME
  value: {{ include "ister.rabbitmqUser" . | quote }}
- name: SPRING_RABBITMQ_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "ister.rabbitmqSecretName" . }}
      key: {{ include "ister.rabbitmqSecretKey" . }}
# --- Typesense
{{- if or .Values.typesense.enabled .Values.typesense.external.host }}
- name: TYPESENSE_ENABLED
  value: "true"
- name: TYPESENSE_HOST
  value: {{ include "ister.typesenseHost" . | quote }}
- name: TYPESENSE_PORT
  value: {{ ternary .Values.typesense.port .Values.typesense.external.port .Values.typesense.enabled | quote }}
- name: TYPESENSE_PROTOCOL
  value: {{ ternary "http" .Values.typesense.external.protocol .Values.typesense.enabled | quote }}
- name: TYPESENSE_COLLECTION
  value: {{ .Values.typesense.collection | quote }}
- name: TYPESENSE_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "ister.typesenseSecretName" . }}
      key: api-key
{{- else }}
- name: TYPESENSE_ENABLED
  value: "false"
{{- end }}
# --- External metadata sources (empty = the real service)
{{- $ext := .Values.server.externalServices }}
{{- range $env, $val := dict
    "SPRING_CLOUD_OPENFEIGN_CLIENT_CONFIG_TMDB_URL" $ext.tmdbApiUrl
    "APP_ISTER_WORKER_TMDB_IMAGE_BASE" $ext.tmdbImageBase
    "APP_ISTER_WORKER_MUSICBRAINZ_BASE" $ext.musicbrainzBase
    "APP_ISTER_WORKER_MUSICBRAINZ_COVERART_RELEASE_BASE" $ext.coverArtReleaseBase
    "APP_ISTER_WORKER_MUSICBRAINZ_COVERART_RELEASE_GROUP_BASE" $ext.coverArtReleaseGroupBase
    "APP_ISTER_WORKER_MUSICBRAINZ_COMMONS_FILEPATH_BASE" $ext.commonsFilepathBase
    "APP_ISTER_WORKER_OPENLIBRARY_BASE" $ext.openLibraryBase
    "APP_ISTER_WORKER_OPENLIBRARY_COVERS_BASE" $ext.openLibraryCoversBase
    "APP_ISTER_WORKER_OPENLIBRARY_AUTHOR_PHOTO_BASE" $ext.openLibraryAuthorPhotoBase
    "APP_ISTER_WORKER_WIKIDATA_ENTITY_BASE" $ext.wikidataEntityBase
    "APP_ISTER_WORKER_WIKIDATA_API_BASE" $ext.wikidataApiBase
    "APP_ISTER_WORKER_WIKIPEDIA_SUMMARY_TEMPLATE" $ext.wikipediaSummaryTemplate
    "APP_ISTER_API_PODCAST_ITUNES_BASE" $ext.itunesBase }}
{{- if $val }}
- name: {{ $env }}
  value: {{ $val | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Helper-node settings (app.ister.helper.*) from a {disks, jobs, offloadJobs, concurrency} map.
Usage: {{ include "ister.helperEnv" .Values.server.helper | nindent 12 }}
*/}}
{{- define "ister.helperEnv" -}}
{{- range $i, $disk := .disks }}
- name: APP_ISTER_HELPER_DISKS_{{ $i }}_NAME
  value: {{ required "helper disks[].name is required" $disk.name | quote }}
{{- with $disk.jobs }}
- name: APP_ISTER_HELPER_DISKS_{{ $i }}_JOBS
  value: {{ join "," . | quote }}
{{- end }}
{{- end }}
{{- with .jobs }}
- name: APP_ISTER_HELPER_JOBS
  value: {{ join "," . | quote }}
{{- end }}
{{- with .offloadJobs }}
- name: APP_ISTER_HELPER_OFFLOAD_JOBS
  value: {{ join "," . | quote }}
{{- end }}
{{- with .concurrency }}
- name: APP_ISTER_HELPER_CONCURRENCY
  value: {{ . | quote }}
{{- end }}
{{- end }}

{{/*
Hardware acceleration, from a {type, device, resources, hostPath, privileged, supplementalGroups} map.
*/}}
{{- define "ister.hwaccelEnv" -}}
{{- if and .type (ne .type "none") }}
- name: HLS_HWACCEL
  value: {{ .type | quote }}
- name: HLS_HWACCEL_DEVICE
  value: {{ .device | quote }}
{{- end }}
{{- end }}

{{- define "ister.hwaccelVolumeMounts" -}}
{{- if and .hostPath .type (ne .type "none") }}
- name: hwaccel-device
  mountPath: {{ .device }}
{{- end }}
{{- end }}

{{- define "ister.hwaccelVolumes" -}}
{{- if and .hostPath .type (ne .type "none") }}
- name: hwaccel-device
  hostPath:
    path: {{ .device }}
    type: CharDevice
{{- end }}
{{- end }}

{{/* Container securityContext with the hwaccel privilege escape hatch applied. */}}
{{- define "ister.serverContainerSecurityContext" -}}
{{- $sc := deepCopy .base -}}
{{- if and .hwaccel.privileged .hwaccel.type (ne .hwaccel.type "none") -}}
{{- $_ := set $sc "privileged" true -}}
{{- $_ := unset $sc "capabilities" -}}
{{/*
The API server rejects privileged together with allowPrivilegeEscalation: false
("cannot set `allowPrivilegeEscalation` to false and `privileged` to true"), and the
base securityContext sets exactly that. Without this the render is valid YAML that
kubectl refuses to apply.
*/}}
{{- $_ := set $sc "allowPrivilegeEscalation" true -}}
{{- end -}}
{{- toYaml $sc -}}
{{- end }}

{{/* Pod securityContext with hwaccel.supplementalGroups merged in. */}}
{{- define "ister.serverPodSecurityContext" -}}
{{- $sc := deepCopy .base -}}
{{- if and .hwaccel.supplementalGroups .hwaccel.type (ne .hwaccel.type "none") -}}
{{- $_ := set $sc "supplementalGroups" (concat (default list $sc.supplementalGroups) .hwaccel.supplementalGroups) -}}
{{- end -}}
{{- toYaml $sc -}}
{{- end }}

{{/* Container resources with hwaccel.resources merged into the limits. */}}
{{- define "ister.serverResources" -}}
{{- $res := deepCopy .base -}}
{{- if and .hwaccel.resources .hwaccel.type (ne .hwaccel.type "none") -}}
{{- $_ := set $res "limits" (merge (default dict $res.limits) .hwaccel.resources) -}}
{{- end -}}
{{- toYaml $res -}}
{{- end }}

{{/*
Render a volume source for an entry of server.mediaVolumes.
Each entry has exactly one of: hostPath, existingClaim, nfs.
*/}}
{{- define "ister.mediaVolumeSource" -}}
{{- if .hostPath }}
hostPath:
  path: {{ .hostPath }}
  type: {{ default "Directory" .hostPathType }}
{{- else if .existingClaim }}
persistentVolumeClaim:
  claimName: {{ .existingClaim }}
{{- else if .nfs }}
nfs:
  {{- toYaml .nfs | nindent 2 }}
{{- else }}
{{- fail (printf "server.mediaVolumes entry %q must set one of: hostPath, existingClaim, nfs" .name) }}
{{- end }}
{{- end }}
