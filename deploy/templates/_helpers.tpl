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

{{/* The two hostnames, required everywhere. */}}
{{- define "pixelaudit.apiHost" -}}
{{- required "hosts.api is required" .Values.hosts.api -}}
{{- end }}

{{- define "pixelaudit.adminHost" -}}
{{- required "hosts.admin is required" .Values.hosts.admin -}}
{{- end }}

{{/* The scheme both hostnames are served under. */}}
{{- define "pixelaudit.scheme" -}}
{{- if .Values.hosts.tls -}}https{{- else -}}http{{- end -}}
{{- end }}

{{/* The TLS Secret the Ingress or the Gateway serves, when none is named. */}}
{{- define "pixelaudit.defaultTlsSecretName" -}}
{{- printf "%s-tls" (include "pixelaudit.fullname" .) -}}
{{- end }}

{{/* The chart's own Postgres: its Service, its password Secret. */}}
{{- define "pixelaudit.postgresName" -}}
{{- printf "%s-postgres" (include "pixelaudit.fullname" .) -}}
{{- end }}

{{- define "pixelaudit.postgresPasswordSecretName" -}}
{{- .Values.database.internal.passwordSecret.name | default (include "pixelaudit.postgresName" .) -}}
{{- end }}

{{/* Whether the chart runs its own Postgres; refuses both or neither. */}}
{{- define "pixelaudit.internalDatabase" -}}
{{- if and .Values.database.internal.enabled .Values.database.external.secretName -}}
{{- fail "set either database.external.secretName or database.internal.enabled, not both" -}}
{{- else if .Values.database.internal.enabled -}}
true
{{- else if not .Values.database.external.secretName -}}
{{- fail "a database is required: database.external.secretName (a Secret holding DATABASE_URL) or database.internal.enabled" -}}
{{- end -}}
{{- end }}

{{/*
The API's environment, shared by the boot Job and the API Deployment so
both see the same database, keys and CONNECTION_* variables. DATABASE_URL
comes from the external Secret, or is built for the chart's own Postgres
with the password read from its Secret; the two secrets from secrets.secretName.
*/}}
{{- define "pixelaudit.apiEnv" -}}
{{- $secrets := required "secrets.secretName is required: a Secret holding WEB_SECRET_KEY_BASE and CREDENTIALS_ENCRYPTION_KEY" .Values.secrets.secretName -}}
- name: PORT
  value: {{ .Values.api.port | quote }}
- name: HOSTNAME
  value: {{ include "pixelaudit.apiHost" . | quote }}
- name: DATABASE_POOL_SIZE
  value: {{ .Values.api.poolSize | quote }}
- name: CORS_ORIGINS
  value: {{ include "pixelaudit.corsOrigins" . | quote }}
{{- if include "pixelaudit.internalDatabase" . }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "pixelaudit.postgresPasswordSecretName" . }}
      key: {{ .Values.database.internal.passwordSecret.key }}
- name: DATABASE_URL
  value: {{ printf "postgres://%s:$(POSTGRES_PASSWORD)@%s:5432/%s" .Values.database.internal.username (include "pixelaudit.postgresName" .) .Values.database.internal.database | quote }}
{{- else }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.external.secretName }}
      key: {{ .Values.database.external.secretKey }}
{{- end }}
- name: WEB_SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      name: {{ $secrets }}
      key: {{ .Values.secrets.keys.webSecretKeyBase }}
- name: CREDENTIALS_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secrets }}
      key: {{ .Values.secrets.keys.credentialsEncryptionKey }}
{{- with .Values.api.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/* The panel's origin, then whatever api.corsOrigins adds. */}}
{{- define "pixelaudit.corsOrigins" -}}
{{- $origins := list (printf "%s://%s" (include "pixelaudit.scheme" .) (include "pixelaudit.adminHost" .)) -}}
{{- range .Values.api.corsOrigins }}{{ $origins = append $origins . }}{{ end -}}
{{- join "," $origins -}}
{{- end }}

{{- define "pixelaudit.apiEnvFrom" -}}
{{- with .Values.api.extraEnvFrom }}
envFrom:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end }}
