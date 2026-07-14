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
{{- end }}

{{/*
Render an image reference from a {repository, tag, digest, pullPolicy} map.
Falls back to .Chart.AppVersion when tag is empty, so a chart release pins its app version.
Usage: {{ include "ister.image" (dict "ctx" . "image" .Values.server.image) }}
*/}}
{{- define "ister.image" -}}
{{- $img := .image -}}
{{- if $img.digest -}}
{{- printf "%s@%s" $img.repository $img.digest -}}
{{- else -}}
{{- printf "%s:%s" $img.repository (default .ctx.Chart.AppVersion $img.tag) -}}
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
When the Bitnami subchart is enabled we must reproduce its resource names, because
its Service and Secret are named by *its* fullname template, not ours.
*/}}

{{- define "ister.rabbitmqSubchartFullname" -}}
{{- $rmq := .Values.rabbitmq -}}
{{- if $rmq.fullnameOverride -}}
{{- $rmq.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if contains "rabbitmq" .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-rabbitmq" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "ister.rabbitmqHost" -}}
{{- if .Values.rabbitmq.enabled -}}
{{- include "ister.rabbitmqSubchartFullname" . -}}
{{- else -}}
{{- required "externalRabbitmq.host is required when rabbitmq.enabled is false" .Values.externalRabbitmq.host -}}
{{- end -}}
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
{{- default (include "ister.rabbitmqSubchartFullname" .) .Values.rabbitmq.auth.existingPasswordSecret -}}
{{- else -}}
{{- default (printf "%s-rabbitmq" (include "ister.fullname" .)) .Values.externalRabbitmq.existingSecret -}}
{{- end -}}
{{- end }}

{{/* Both the Bitnami chart and our external Secret use this key. */}}
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
{{- else -}}
{{- printf "http://localhost:8080%s" .Values.server.contextPath -}}
{{- end -}}
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
