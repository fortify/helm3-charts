{{/*
Expand the name of the chart.
*/}}
{{- define "dast.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dast.fullname" -}}
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

{{- define "dast-api.fullname" -}}
{{- printf "%s-api" (include "dast.fullname" .) }}
{{- end }}
{{- define "dast-globalservice.fullname" -}}
{{- printf "%s-globalservice" (include "dast.fullname" .) }}
{{- end }}
{{- define "dast-scanner.fullname" -}}
{{- .Values.scanner.nameOverride | default (printf "%s-scanner" (include "dast.fullname" .)) }}
{{- end }}
{{- define "dast-twofactorauth.fullname" -}}
{{- printf "%s-twofactorauth" (include "dast.fullname" .) }}
{{- end }}
{{- define "dast-utilityservice.fullname" -}}
{{- printf "%s-utilityservice" (include "dast.fullname" .) }}
{{- end }}
{{- define "dast-wise.fullname" -}}
{{- printf "%s-wise" (include "dast.fullname" .) }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dast.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dast.labels" -}}
tier: dast
helm.sh/chart: {{ include "dast.chart" . }}
{{ include "dast.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dast.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dast.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Secret Name
*/}}
{{- define "secret.name" -}}
{{- .Values.secretName | default (include "dast.fullname" .) -}}
{{- end -}}
