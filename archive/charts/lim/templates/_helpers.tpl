{{/*
Expand the name of the chart.
*/}}
{{- define "lim.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "lim.fullname" -}}
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
{{- define "lim.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "lim.labels" -}}
helm.sh/chart: {{ include "lim.chart" . }}
{{ include "lim.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lim.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lim.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Secret Name
*/}}
{{- define "lim-secret.fullname" -}}
{{- .Values.secretName | default (include "lim.fullname" .) -}}
{{- end -}}

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
