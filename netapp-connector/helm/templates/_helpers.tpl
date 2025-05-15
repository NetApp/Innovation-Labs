{{/* Generate a fullname combining release name and chart name */}}
{{- define "netapp-connector.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "netapp-connector.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Chart name */}}
{{- define "netapp-connector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
