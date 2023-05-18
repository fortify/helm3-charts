{{/*
Expand the name of the chart.
*/}}
{{- define "scancentral-sast.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "scancentral-sast.fullname" -}}
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
{{- define "scancentral-sast.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "scancentral-sast.labels" -}}
helm.sh/chart: {{ include "scancentral-sast.chart" . }}
{{ include "scancentral-sast.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "scancentral-sast.selectorLabels" -}}
app.kubernetes.io/name: {{ include "scancentral-sast.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "scancentral-sast-controller.fullname" -}}
{{- printf "%s-controller" (include "scancentral-sast.fullname" .) }}
{{- end }}

{{- define "scancentral-sast-secret.fullname" -}}
{{- .Values.secrets.secretName | default (include "scancentral-sast.fullname" .) }}
{{- end }}

{{- define "scancentral-sast-certificates.fullname" -}}
{{- printf "%s-certificates" (include "scancentral-sast.fullname" .) }}
{{- end }}

{{- define "secrets.passwords.manage" -}}
{{- $password := "" }}
{{- $providedPassword := .providedPassword }}
{{- $passwordLength := default 10 .length }}
{{- $secretData := (lookup "v1" "Secret" $.context.Release.Namespace .secret).data }}
{{- if $secretData }}
  {{- if hasKey $secretData .key }}
    {{- $password = index $secretData .key }}
  {{- else }}
    {{- printf "\nPASSWORDS ERROR: The secret \"%s\" does not contain the key \"%s\"\n" .secret .key | fail -}}
  {{- end -}}
{{- else if $providedPassword }}
  {{- $password = $providedPassword | toString | b64enc | quote }}
{{- else }}
  {{- $password = randAlphaNum $passwordLength | b64enc | quote }}
{{- end }}
{{- printf "%s" $password -}}
{{- end -}}

{{- define "anyWorkerEnabled" -}}
{{ $anyWorkerEnabled := false }}
{{- range $k, $v := .Values.workers }}
{{- if $v.enabled }}
{{- $anyWorkerEnabled = true }}
{{- end }}
{{- end }}
{{ $anyWorkerEnabled }}
{{- end }}