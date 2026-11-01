{{/*
Names and labels, the Helm way: the release name unless it already holds
the chart name.
*/}}
{{- define "pixelaudit.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "pixelaudit.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "pixelaudit.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "pixelaudit.labels" -}}
helm.sh/chart: {{ include "pixelaudit.chart" . }}
app.kubernetes.io/name: {{ include "pixelaudit.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Labels of one component's pods: pass (dict "root" . "component" "api"). */}}
{{- define "pixelaudit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pixelaudit.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "pixelaudit.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "pixelaudit.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end }}

{{/*
The image tag every container runs: `latest` when image.trackLatest, else
image.tag, else the chart's appVersion. The boot Job and both Deployments
go through this and pixelaudit.imagePullPolicy, so they always agree.
*/}}
{{- define "pixelaudit.imageTag" -}}
{{- if .Values.image.trackLatest -}}latest{{- else -}}{{ .Values.image.tag | default .Chart.AppVersion }}{{- end -}}
{{- end }}

{{- define "pixelaudit.imagePullPolicy" -}}
{{- if .Values.image.trackLatest -}}Always{{- else -}}{{ .Values.image.pullPolicy }}{{- end -}}
{{- end }}

{{/* <registry>/<repository>-<component>:<tag>; pass (dict "root" . "component" "api"). */}}
{{- define "pixelaudit.image" -}}
{{- printf "%s/%s-%s:%s" .root.Values.image.registry .root.Values.image.repository .component (include "pixelaudit.imageTag" .root) -}}
{{- end }}

{{- define "pixelaudit.imagePullSecrets" -}}
{{- with .Values.image.pullSecrets }}
imagePullSecrets:
{{- range . }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/* The scheme both hostnames are served under. */}}
{{- define "pixelaudit.scheme" -}}
{{- if .Values.ingress.tls -}}https{{- else -}}http{{- end -}}
{{- end }}

{{/* The Secret the chart renders for the API, holding what was given inline. */}}
{{- define "pixelaudit.apiSecretName" -}}
{{- printf "%s-api" (include "pixelaudit.fullname" .) -}}
{{- end }}

{{- define "pixelaudit.renderApiSecret" -}}
{{- if or .Values.database.url .Values.secrets.secretKeyBase .Values.secrets.secretKey -}}true{{- end -}}
{{- end }}

{{/* The Secret the SECRET_KEY_BASE and SECRET_KEY are read from. */}}
{{- define "pixelaudit.secretsSecretName" -}}
{{- .Values.secrets.existingSecret | default (include "pixelaudit.apiSecretName" .) -}}
{{- end }}

{{/*
The API's environment, shared by the boot Job and the API Deployment so
both see the same database, keys and CONNECTION_* variables. DATABASE_URL
comes from, in this order: database.url (the chart's Secret),
database.existingSecret, or the in-chart postgresql (built from its auth
values, the password read from the subchart's Secret).
*/}}
{{- define "pixelaudit.apiEnv" -}}
- name: PORT
  value: {{ .Values.api.port | quote }}
- name: HOSTNAME
  value: {{ required "api.hostname is required" .Values.api.hostname | quote }}
- name: DATABASE_POOL_SIZE
  value: {{ .Values.api.poolSize | quote }}
- name: CORS_ORIGINS
  value: {{ include "pixelaudit.corsOrigins" . | quote }}
{{- if .Values.database.url }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "pixelaudit.apiSecretName" . }}
      key: DATABASE_URL
{{- else if .Values.database.existingSecret }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.existingSecret }}
      key: {{ .Values.database.existingSecretKey }}
{{- else if .Values.postgresql.enabled }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-postgresql
      key: password
- name: DATABASE_URL
  value: {{ printf "postgres://%s:$(POSTGRES_PASSWORD)@%s-postgresql:5432/%s" .Values.postgresql.auth.username .Release.Name .Values.postgresql.auth.database | quote }}
{{- else }}
{{- fail "a database is required: set database.url, database.existingSecret, or postgresql.enabled" }}
{{- end }}
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      name: {{ include "pixelaudit.secretsSecretName" . }}
      key: SECRET_KEY_BASE
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "pixelaudit.secretsSecretName" . }}
      key: SECRET_KEY
{{- with .Values.api.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/* The panel's origin, then whatever api.corsOrigins adds. */}}
{{- define "pixelaudit.corsOrigins" -}}
{{- $origins := list (printf "%s://%s" (include "pixelaudit.scheme" .) (required "admin.hostname is required" .Values.admin.hostname)) -}}
{{- range .Values.api.corsOrigins }}{{ $origins = append $origins . }}{{ end -}}
{{- join "," $origins -}}
{{- end }}

{{- define "pixelaudit.apiEnvFrom" -}}
{{- with .Values.api.extraEnvFrom }}
envFrom:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end }}
