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

{{/* Labels of one component's pods: pass (dict "root" . "component" "app"). */}}
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
image.tag, else the chart's appVersion. The boot Job and the Deployment go
through this and pixelaudit.imagePullPolicy, so they always agree.
*/}}
{{- define "pixelaudit.imageTag" -}}
{{- if .Values.image.trackLatest -}}latest{{- else -}}{{ .Values.image.tag | default .Chart.AppVersion }}{{- end -}}
{{- end }}

{{- define "pixelaudit.imagePullPolicy" -}}
{{- if .Values.image.trackLatest -}}Always{{- else -}}{{ .Values.image.pullPolicy }}{{- end -}}
{{- end }}

{{/* <registry>/<repository>:<tag> — the one image, API and panel together. */}}
{{- define "pixelaudit.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository (include "pixelaudit.imageTag" .) -}}
{{- end }}

{{- define "pixelaudit.imagePullSecrets" -}}
{{- with .Values.image.pullSecrets }}
imagePullSecrets:
{{- range . }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/* The one hostname, required everywhere. */}}
{{- define "pixelaudit.hostname" -}}
{{- required "hostname is required" .Values.hostname -}}
{{- end }}

{{/* The scheme the hostname is served under. */}}
{{- define "pixelaudit.scheme" -}}
{{- if .Values.tls -}}https{{- else -}}http{{- end -}}
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
The application's environment, shared by the boot Job and the Deployment
so both see the same database, secrets and CONNECTION_* variables.
DATABASE_URL comes from the external Secret, or is built for the chart's
own Postgres with the password read from its Secret; the two secrets from
secrets.secretName.
*/}}
{{- define "pixelaudit.appEnv" -}}
{{- $secrets := required "secrets.secretName is required: a Secret holding WEB_SECRET_KEY_BASE and CREDENTIALS_ENCRYPTION_KEY" .Values.secrets.secretName -}}
- name: PORT
  value: {{ .Values.app.port | quote }}
- name: HOSTNAME
  value: {{ include "pixelaudit.hostname" . | quote }}
- name: SOURCE_URL
  value: {{ .Values.sourceUrl | quote }}
- name: DATABASE_POOL_SIZE
  value: {{ .Values.app.poolSize | quote }}
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
{{- with .Values.app.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "pixelaudit.appEnvFrom" -}}
{{- with .Values.app.extraEnvFrom }}
envFrom:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end }}
