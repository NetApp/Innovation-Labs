{{/* Generate a fullname combining release name and chart name */}}
{{- define "netapp-connector.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "netapp-connector.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Chart name */}}
{{- define "netapp-connector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Generate database URL for built-in PostgreSQL */}}
{{- define "netapp-connector.databaseUrl" -}}
{{- if .Values.postgresql.enabled -}}
postgresql://{{ .Values.postgresql.auth.username }}:{{ .Values.postgresql.auth.password }}@{{ .Values.postgresql.name }}:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.auth.database }}
{{- else -}}
{{ .Values.main.env.DATABASE_URL }}
{{- end -}}
{{- end -}}
