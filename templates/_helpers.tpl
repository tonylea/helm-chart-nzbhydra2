{{- define "nzbhydra2.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "nzbhydra2.labels" -}}
{{ include "nzbhydra2.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{/* Without the chart's version, so a release that changes only the chart doesn't restart NZBHydra2. */}}
{{- define "nzbhydra2.podLabels" -}}
{{ include "nzbhydra2.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{- define "nzbhydra2.secretKeyRef" -}}
{{- $path := index . 0 }}
{{- $ref := (index . 1).secretKeyRef }}
secretKeyRef:
  name: {{ required (printf "%s.secretKeyRef.name is required" $path) $ref.name }}
  key: {{ required (printf "%s.secretKeyRef.key is required" $path) $ref.key }}
{{- end }}

{{/* The yq expression that sets the managed keys; secrets are read from the init container's environment. */}}
{{- define "nzbhydra2.settingsExpression" -}}
{{- $indexers := list }}
{{- range $i, $indexer := .Values.indexers }}
{{- $indexers = append $indexers (printf `{"name": %s, "host": %s, "apiKey": strenv(INDEXER_%d_API_KEY), "searchModuleType": "NEWZNAB", "state": "ENABLED"}` (required (printf "indexers[%d].name is required" $i) $indexer.name | toJson) (required (printf "indexers[%d].host is required" $i) $indexer.host | toJson) $i) }}
{{- end }}
.main.apiKey = strenv(API_KEY) |
.auth.authType = "FORM" |
.auth.users = [{"username": strenv(AUTH_USERNAME), "password": "{noop}" + strenv(AUTH_PASSWORD), "maySeeAdmin": true, "maySeeStats": true, "maySeeDetailsDl": true, "showIndexerSelection": true}] |
.indexers = [{{ join ", " $indexers }}]
{{- end }}

{{- define "nzbhydra2.claimName" -}}
{{- .Values.persistence.config.existingClaim | default (printf "%s-config" .Release.Name) }}
{{- end }}
