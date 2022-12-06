{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "ssc.name" -}}
{{- .Values.nameOverride | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ssc.componentname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" $name .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ssc.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified component name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "ssc.fullcomponentname" -}}
{{- $fullname := include "ssc.fullname" . | trunc (int (sub 62 (.component | len))) | trimSuffix "-" -}}
{{- printf "%s-%s" $fullname .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ssc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "ssc.labels" -}}
app.kubernetes.io/name: {{ include "ssc.name" . }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "ssc.chart" . }}
{{- end -}}


{{/*
Common selector
*/}}
{{- define "ssc.selector" -}}
app.kubernetes.io/name: {{ include "ssc.name" . }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Image tag
*/}}
{{- define "ssc.image.tag" -}}
{{- if hasKey .Values.image "tag" -}}
{{- .Values.image.tag -}}
{{- else if .Values.image.buildNumber -}}
{{- .Chart.AppVersion -}}.{{- .Values.image.buildNumber -}}
{{- else -}}
{{- .Chart.AppVersion -}}
{{- end -}}
{{- end -}}
