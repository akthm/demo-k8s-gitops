{{/*
Expand the name of the chart.
*/}}
{{- define "platform-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "platform-app.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "platform-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "platform-app.labels" -}}
helm.sh/chart: {{ include "platform-app.chart" . }}
{{ include "platform-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: platform-app
{{- end }}

{{/*
Selector labels
*/}}
{{- define "platform-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
OAuth2 Proxy name
*/}}
{{- define "platform-app.oauth2proxy.name" -}}
{{- printf "%s-oauth2-proxy" (include "platform-app.fullname" .) }}
{{- end }}

{{/*
OAuth2 Proxy selector labels
*/}}
{{- define "platform-app.oauth2proxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-app.name" . }}-oauth2-proxy
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: oauth2-proxy
{{- end }}

{{/*
Redis connection URL for oauth2-proxy
*/}}
{{- define "platform-app.redis.url" -}}
{{- if .Values.global.bff.redis.external.enabled }}
{{- .Values.global.bff.redis.external.url }}
{{- else }}
{{- if .Values.redis.auth.enabled }}
{{- printf "redis://:%s@%s-redis-master:6379" "$(REDIS_PASSWORD)" .Release.Name }}
{{- else }}
{{- printf "redis://%s-redis-master:6379" .Release.Name }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Backend service URL (internal cluster DNS)
*/}}
{{- define "platform-app.backend.url" -}}
{{- printf "%s-backend:%d" .Release.Name (int .Values.backend.service.port) }}
{{- end }}

{{/*
Frontend service URL (internal cluster DNS)
*/}}
{{- define "platform-app.frontend.url" -}}
{{- printf "%s-frontend:%d" .Release.Name (int .Values.frontend.service.port) }}
{{- end }}

{{/*
OAuth2 Proxy callback URL
*/}}
{{- define "platform-app.oauth2proxy.callbackUrl" -}}
{{- $scheme := "https" }}
{{- if not .Values.global.tls.enabled }}
{{- $scheme = "http" }}
{{- end }}
{{- printf "%s://%s/oauth2/callback" $scheme .Values.global.domain }}
{{- end }}

{{/*
Keycloak issuer URL
*/}}
{{- define "platform-app.keycloak.issuerUrl" -}}
{{- printf "%s/realms/%s" .Values.global.keycloak.url .Values.global.keycloak.realm }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "platform-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "platform-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create OAuth2 Proxy secret name
*/}}
{{- define "platform-app.oauth2proxy.secretName" -}}
{{- printf "%s-oauth2-proxy-secrets" (include "platform-app.fullname" .) }}
{{- end }}

{{/*
Create BFF internal secret name
*/}}
{{- define "platform-app.bff.internalSecretName" -}}
{{- printf "%s-bff-internal" (include "platform-app.fullname" .) }}
{{- end }}
