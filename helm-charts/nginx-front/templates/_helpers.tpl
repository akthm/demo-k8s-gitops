{{- define "nginx-front.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "nginx-front.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "nginx-front.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "nginx-front.labels" -}}
app.kubernetes.io/name: {{ include "nginx-front.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "nginx-front.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nginx-front.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
