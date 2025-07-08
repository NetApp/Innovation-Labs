{{/*
Expand the name of the chart.
*/}}
{{- define "netapp-openshift-console-protect.name" -}}
{{- default (default .Chart.Name .Release.Name) .Values.plugin.name | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "netapp-openshift-console-protect.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "netapp-openshift-console-protect.labels" -}}
helm.sh/chart: {{ include "netapp-openshift-console-protect.chart" . }}
{{ include "netapp-openshift-console-protect.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "netapp-openshift-console-protect.selectorLabels" -}}
app: {{ include "netapp-openshift-console-protect.name" . }}
app.kubernetes.io/name: {{ include "netapp-openshift-console-protect.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "netapp-openshift-console-protect.name" . }}
{{- end }}

{{/*
Create the name secret containing the certificate
*/}}
{{- define "netapp-openshift-console-protect.certificateSecret" -}}
{{ default (printf "%s-cert" (include "netapp-openshift-console-protect.name" .)) .Values.plugin.certificateSecretName }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "netapp-openshift-console-protect.serviceAccountName" -}}
{{- if .Values.plugin.serviceAccount.create }}
{{- default (include "netapp-openshift-console-protect.name" .) .Values.plugin.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.plugin.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the patcher
*/}}
{{- define "netapp-openshift-console-protect.patcherName" -}}
{{- printf "%s-patcher" (include "netapp-openshift-console-protect.name" .) }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "netapp-openshift-console-protect.patcherServiceAccountName" -}}
{{- if .Values.plugin.patcherServiceAccount.create }}
{{- default (printf "%s-patcher" (include "netapp-openshift-console-protect.name" .)) .Values.plugin.patcherServiceAccount.name }}
{{- else }}
{{- default "default" .Values.plugin.patcherServiceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the secret to access the private image repository
*/}}
{{- define "imagePullSecret" }}
{{- with .Values.plugin.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .token (printf "%s:%s" .username .token | b64enc) | b64enc }}
{{- end }}
{{- end }}