{{/*
Chart name, truncated to 63 chars.
*/}}
{{- define "netapp-neo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name: <release>-<chart>
*/}}
{{- define "netapp-neo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "netapp-neo.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Component name: <fullname>-<component>
*/}}
{{- define "netapp-neo.componentName" -}}
{{- printf "%s-%s" (include "netapp-neo.fullname" .) . | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "netapp-neo.labels" -}}
app.kubernetes.io/name: {{ include "netapp-neo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Selector labels for a component.
Usage: include "netapp-neo.selectorLabels" (dict "context" . "component" "api")
*/}}
{{- define "netapp-neo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netapp-neo.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Construct DATABASE_URL.
When postgresql.enabled, builds from auth creds and service name.
Otherwise uses postgresql.externalDatabaseUrl.
*/}}
{{- define "netapp-neo.databaseUrl" -}}
{{- if .Values.postgresql.enabled -}}
postgresql://{{ .Values.postgresql.auth.username }}:{{ .Values.postgresql.auth.password }}@{{ include "netapp-neo.fullname" . }}-postgres:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.auth.database }}
{{- else -}}
{{ .Values.postgresql.externalDatabaseUrl }}
{{- end -}}
{{- end -}}

{{/*
Inter-service URL helpers.
These construct cluster-internal URLs so users never configure them manually.
*/}}
{{- define "netapp-neo.apiUrl" -}}
http://{{ include "netapp-neo.fullname" . }}-api:{{ .Values.api.service.port }}
{{- end -}}

{{- define "netapp-neo.workerUrl" -}}
http://{{ include "netapp-neo.fullname" . }}-worker:{{ .Values.worker.service.port }}
{{- end -}}

{{- define "netapp-neo.extractorUrl" -}}
http://{{ include "netapp-neo.fullname" . }}-extractor:{{ .Values.extractor.service.port }}
{{- end -}}

{{- define "netapp-neo.nerUrl" -}}
http://{{ include "netapp-neo.fullname" . }}-ner:{{ .Values.ner.service.port }}
{{- end -}}

{{/*
Wait-for-db init container (reusable).
Usage: include "netapp-neo.waitForDb" .
Only useful when postgresql.enabled is true.
*/}}
{{- define "netapp-neo.waitForDb" -}}
- name: wait-for-db
  image: "{{ .Values.postgresql.image.repository }}:{{ .Values.postgresql.image.tag }}"
  command:
    - sh
    - -c
    - |
      until pg_isready \
        -h {{ include "netapp-neo.fullname" . }}-postgres \
        -p {{ .Values.postgresql.service.port }} \
        -U {{ .Values.postgresql.auth.username }} \
        -d {{ .Values.postgresql.auth.database }}; do
        echo "Waiting for PostgreSQL…"
        sleep 2
      done
      echo "PostgreSQL is ready!"
  env:
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "netapp-neo.fullname" . }}-db
          key: POSTGRES_PASSWORD
{{- end -}}

{{/*
Resolve image tag — falls back to Chart.AppVersion when tag is empty.
Usage: include "netapp-neo.imageTag" (dict "imageTag" .Values.api.image.tag "appVersion" .Chart.AppVersion)
*/}}
{{- define "netapp-neo.imageTag" -}}
{{- default .appVersion .imageTag -}}
{{- end -}}
