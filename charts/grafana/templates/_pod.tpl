
{{- define "grafana.pod" -}}
{{- if .Values.schedulerName }}
schedulerName: "{{ .Values.schedulerName }}"
{{- end }}
serviceAccountName: {{ template "grafana.serviceAccountName" . }}
automountServiceAccountToken: {{ .Values.serviceAccount.autoMount }}
{{- if .Values.securityContext }}
securityContext:
{{ toYaml .Values.securityContext | indent 2 }}
{{- end }}
{{- if .Values.hostAliases }}
hostAliases:
{{ toYaml .Values.hostAliases | indent 2 }}
{{- end }}
{{- if .Values.priorityClassName }}
priorityClassName: {{ .Values.priorityClassName }}
{{- end }}
{{- if ( or .Values.persistence.enabled .Values.dashboards .Values.sidecar.notifiers.enabled .Values.extraInitContainers (and .Values.sidecar.datasources.enabled .Values.sidecar.datasources.initDatasources)) }}
initContainers:
{{- end }}
{{- if ( and .Values.persistence.enabled .Values.initChownData.enabled ) }}
  - name: init-chown-data
    {{- if .Values.initChownData.image.sha }}
    image: "{{ .Values.initChownData.image.repository }}:{{ .Values.initChownData.image.tag }}@sha256:{{ .Values.initChownData.image.sha }}"
    {{- else }}
    image: "{{ .Values.initChownData.image.repository }}:{{ .Values.initChownData.image.tag }}"
    {{- end }}
    imagePullPolicy: {{ .Values.initChownData.image.pullPolicy }}
    securityContext:
      runAsNonRoot: false
      runAsUser: 0
    command: ["chown", "-R", "{{ .Values.securityContext.runAsUser }}:{{ .Values.securityContext.runAsGroup }}", "/var/lib/grafana"]
    resources:
{{ toYaml .Values.initChownData.resources | indent 6 }}
    volumeMounts:
      - name: storage
        mountPath: "/var/lib/grafana"
{{- if .Values.persistence.subPath }}
        subPath: {{ tpl .Values.persistence.subPath . }}
{{- end }}
{{- end }}
{{- if .Values.dashboards }}
  - name: download-dashboards
    {{- if .Values.downloadDashboardsImage.sha }}
    image: "{{ .Values.downloadDashboardsImage.repository }}:{{ .Values.downloadDashboardsImage.tag }}@sha256:{{ .Values.downloadDashboardsImage.sha }}"
    {{- else }}
    image: "{{ .Values.downloadDashboardsImage.repository }}:{{ .Values.downloadDashboardsImage.tag }}"
    {{- end }}
    imagePullPolicy: {{ .Values.downloadDashboardsImage.pullPolicy }}
    command: ["/bin/sh"]
    args: [ "-c", "mkdir -p /var/lib/grafana/dashboards/default && /bin/sh -x /etc/grafana/download_dashboards.sh" ]
    resources:
{{ toYaml .Values.downloadDashboards.resources | indent 6 }}
    env:
{{- range $key, $value := .Values.downloadDashboards.env }}
      - name: "{{ $key }}"
        value: "{{ $value }}"
{{- end }}
{{- if .Values.downloadDashboards.envFromSecret }}
    envFrom:
      - secretRef:
          name: {{ tpl .Values.downloadDashboards.envFromSecret . }}
{{- end }}
    volumeMounts:
      - name: config
        mountPath: "/etc/grafana/download_dashboards.sh"
        subPath: download_dashboards.sh
      - name: storage
        mountPath: "/var/lib/grafana"
{{- if .Values.persistence.subPath }}
        subPath: {{ tpl .Values.persistence.subPath . }}
{{- end }}
    {{- range .Values.extraSecretMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: {{ .readOnly }}
    {{- end }}
{{- end }}
{{- if and .Values.sidecar.datasources.enabled .Values.sidecar.datasources.initDatasources }}
  - name: {{ template "grafana.name" . }}-init-sc-datasources
    {{- if .Values.sidecar.image.sha }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}@sha256:{{ .Values.sidecar.image.sha }}"
    {{- else }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}"
    {{- end }}
    imagePullPolicy: {{ .Values.sidecar.imagePullPolicy }}
    env:
      - name: METHOD
        value: "LIST"
      - name: LABEL
        value: "{{ .Values.sidecar.datasources.label }}"
      {{- if .Values.sidecar.datasources.labelValue }}
      - name: LABEL_VALUE
        value: {{ quote .Values.sidecar.datasources.labelValue }}
      {{- end }}
      - name: FOLDER
        value: "/etc/grafana/provisioning/datasources"
      - name: RESOURCE
        value: {{ quote .Values.sidecar.datasources.resource }}
      {{- if .Values.sidecar.enableUniqueFilenames }}
      - name: UNIQUE_FILENAMES
        value: "{{ .Values.sidecar.enableUniqueFilenames }}"
      {{- end }}
      {{- if .Values.sidecar.datasources.searchNamespace }}
      - name: NAMESPACE
        value: "{{ .Values.sidecar.datasources.searchNamespace | join "," }}"
      {{- end }}
      {{- if .Values.sidecar.skipTlsVerify }}
      - name: SKIP_TLS_VERIFY
        value: "{{ .Values.sidecar.skipTlsVerify }}"
      {{- end }}
    resources:
{{ toYaml .Values.sidecar.resources | indent 6 }}
{{- if .Values.sidecar.securityContext }}
    securityContext:
{{- toYaml .Values.sidecar.securityContext | nindent 6 }}
{{- end }}
    volumeMounts:
      - name: sc-datasources-volume
        mountPath: "/etc/grafana/provisioning/datasources"
{{- end }}
{{- if .Values.sidecar.notifiers.enabled }}
  - name: {{ template "grafana.name" . }}-sc-notifiers
    {{- if .Values.sidecar.image.sha }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}@sha256:{{ .Values.sidecar.image.sha }}"
    {{- else }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}"
    {{- end }}
    imagePullPolicy: {{ .Values.sidecar.imagePullPolicy }}
    env:
      - name: METHOD
        value: LIST
      - name: LABEL
        value: "{{ .Values.sidecar.notifiers.label }}"
      - name: FOLDER
        value: "/etc/grafana/provisioning/notifiers"
      - name: RESOURCE
        value: {{ quote .Values.sidecar.notifiers.resource }}
      {{- if .Values.sidecar.enableUniqueFilenames }}
      - name: UNIQUE_FILENAMES
        value: "{{ .Values.sidecar.enableUniqueFilenames }}"
      {{- end }}
      {{- if .Values.sidecar.notifiers.searchNamespace }}
      - name: NAMESPACE
        value: "{{ .Values.sidecar.notifiers.searchNamespace | join "," }}"
      {{- end }}
      {{- if .Values.sidecar.skipTlsVerify }}
      - name: SKIP_TLS_VERIFY
        value: "{{ .Values.sidecar.skipTlsVerify }}"
      {{- end }}
{{- if .Values.sidecar.livenessProbe }}
    livenessProbe:
{{ toYaml .Values.livenessProbe | indent 6 }}
{{- end }}
{{- if .Values.sidecar.readinessProbe }}
    readinessProbe:
{{ toYaml .Values.readinessProbe | indent 6 }}
{{- end }}
    resources:
{{ toYaml .Values.sidecar.resources | indent 6 }}
{{- if .Values.sidecar.securityContext }}
    securityContext:
{{- toYaml .Values.sidecar.securityContext | nindent 6 }}
{{- end }}
    volumeMounts:
      - name: sc-notifiers-volume
        mountPath: "/etc/grafana/provisioning/notifiers"
{{- end}}
{{- if .Values.extraInitContainers }}
{{ tpl (toYaml .Values.extraInitContainers) . | indent 2 }}
{{- end }}
{{- if .Values.image.pullSecrets }}
imagePullSecrets:
{{- $root := . }}
{{- range .Values.image.pullSecrets }}
  - name: {{ tpl . $root }}
{{- end}}
{{- end }}
{{- if not .Values.enableKubeBackwardCompatibility }}
enableServiceLinks: {{ .Values.enableServiceLinks }}
{{- end }}
containers:
{{- if .Values.sidecar.dashboards.enabled }}
  - name: {{ template "grafana.name" . }}-sc-dashboard
    {{- if .Values.sidecar.image.sha }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}@sha256:{{ .Values.sidecar.image.sha }}"
    {{- else }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}"
    {{- end }}
    imagePullPolicy: {{ .Values.sidecar.imagePullPolicy }}
    env:
      {{- range $key, $value := .Values.sidecar.dashboards.env }}
      - name: "{{ $key }}"
        value: "{{ $value }}"
      {{- end }}
      - name: METHOD
        value: {{ .Values.sidecar.dashboards.watchMethod }}
      - name: LABEL
        value: "{{ .Values.sidecar.dashboards.label }}"
      {{- if .Values.sidecar.dashboards.labelValue }}
      - name: LABEL_VALUE
        value: {{ quote .Values.sidecar.dashboards.labelValue }}
      {{- end }}
      {{- if .Values.sidecar.logLevel }}
      - name: LOG_LEVEL
        value: {{ quote .Values.sidecar.logLevel }}
      {{- end }}
      - name: FOLDER
        value: "{{ .Values.sidecar.dashboards.folder }}{{- with .Values.sidecar.dashboards.defaultFolderName }}/{{ . }}{{- end }}"
      - name: RESOURCE
        value: {{ quote .Values.sidecar.dashboards.resource }}
      {{- if .Values.sidecar.enableUniqueFilenames }}
      - name: UNIQUE_FILENAMES
        value: "{{ .Values.sidecar.enableUniqueFilenames }}"
      {{- end }}
      {{- if .Values.sidecar.dashboards.searchNamespace }}
      - name: NAMESPACE
        value: "{{ .Values.sidecar.dashboards.searchNamespace | join "," }}"
      {{- end }}
      {{- if .Values.sidecar.skipTlsVerify }}
      - name: SKIP_TLS_VERIFY
        value: "{{ .Values.sidecar.skipTlsVerify }}"
      {{- end }}
      {{- if .Values.sidecar.dashboards.folderAnnotation }}
      - name: FOLDER_ANNOTATION
        value: "{{ .Values.sidecar.dashboards.folderAnnotation }}"
      {{- end }}
      {{- if .Values.sidecar.dashboards.script }}
      - name: SCRIPT
        value: "{{ .Values.sidecar.dashboards.script }}"
      {{- end }}
      {{- if .Values.sidecar.dashboards.watchServerTimeout }}
      - name: WATCH_SERVER_TIMEOUT
        value: "{{ .Values.sidecar.dashboards.watchServerTimeout }}"
      {{- end }}
      {{- if .Values.sidecar.dashboards.watchClientTimeout }}
      - name: WATCH_CLIENT_TIMEOUT
        value: "{{ .Values.sidecar.dashboards.watchClientTimeout }}"
      {{- end }}
{{- if .Values.sidecar.livenessProbe }}
    livenessProbe:
{{ toYaml .Values.livenessProbe | indent 6 }}
{{- end }}
{{- if .Values.sidecar.readinessProbe }}
    readinessProbe:
{{ toYaml .Values.readinessProbe | indent 6 }}
{{- end }}
    resources:
{{ toYaml .Values.sidecar.resources | indent 6 }}
{{- if .Values.sidecar.securityContext }}
    securityContext:
{{- toYaml .Values.sidecar.securityContext | nindent 6 }}
{{- end }}
    volumeMounts:
      - name: sc-dashboard-volume
        mountPath: {{ .Values.sidecar.dashboards.folder | quote }}
      {{- if .Values.sidecar.dashboards.extraMounts }}
      {{- toYaml .Values.sidecar.dashboards.extraMounts | trim | nindent 6}}
      {{- end }}
{{- end}}
{{- if .Values.sidecar.datasources.enabled }}
  - name: {{ template "grafana.name" . }}-sc-datasources
    {{- if .Values.sidecar.image.sha }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}@sha256:{{ .Values.sidecar.image.sha }}"
    {{- else }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}"
    {{- end }}
    imagePullPolicy: {{ .Values.sidecar.imagePullPolicy }}
    env:
      - name: METHOD
        value: {{ .Values.sidecar.datasources.watchMethod }}
      - name: LABEL
        value: "{{ .Values.sidecar.datasources.label }}"
      {{- if .Values.sidecar.datasources.labelValue }}
      - name: LABEL_VALUE
        value: {{ quote .Values.sidecar.datasources.labelValue }}
      {{- end }}
      - name: FOLDER
        value: "/etc/grafana/provisioning/datasources"
      - name: RESOURCE
        value: {{ quote .Values.sidecar.datasources.resource }}
      {{- if .Values.sidecar.enableUniqueFilenames }}
      - name: UNIQUE_FILENAMES
        value: "{{ .Values.sidecar.enableUniqueFilenames }}"
      {{- end }}
      {{- if .Values.sidecar.datasources.searchNamespace }}
      - name: NAMESPACE
        value: "{{ .Values.sidecar.datasources.searchNamespace | join "," }}"
      {{- end }}
      {{- if .Values.sidecar.skipTlsVerify }}
      - name: SKIP_TLS_VERIFY
        value: "{{ .Values.sidecar.skipTlsVerify }}"
      {{- end }}
      {{- if and (not .Values.env.GF_SECURITY_ADMIN_USER) (not .Values.env.GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION) }}
      - name: REQ_USERNAME
        valueFrom:
          secretKeyRef:
            name: {{ (tpl .Values.admin.existingSecret .) | default (include "grafana.fullname" .) }}
            key: {{ .Values.admin.userKey | default "admin-user" }}
      {{- end }}
      {{- if and (not .Values.env.GF_SECURITY_ADMIN_PASSWORD) (not .Values.env.GF_SECURITY_ADMIN_PASSWORD__FILE) (not .Values.env.GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION) }}
      - name: REQ_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ (tpl .Values.admin.existingSecret .) | default (include "grafana.fullname" .) }}
            key: {{ .Values.admin.passwordKey | default "admin-password" }}
      {{- end }}
      {{- if not .Values.sidecar.datasources.skipReload }}
      - name: REQ_URL
        value: {{ .Values.sidecar.datasources.reloadURL }}
      - name: REQ_METHOD
        value: POST
      {{- end }}
{{- if .Values.sidecar.livenessProbe }}
    livenessProbe:
{{ toYaml .Values.livenessProbe | indent 6 }}
{{- end }}
{{- if .Values.sidecar.readinessProbe }}
    readinessProbe:
{{ toYaml .Values.readinessProbe | indent 6 }}
{{- end }}
    resources:
{{ toYaml .Values.sidecar.resources | indent 6 }}
{{- if .Values.sidecar.securityContext }}
    securityContext:
{{- toYaml .Values.sidecar.securityContext | nindent 6 }}
{{- end }}
    volumeMounts:
      - name: sc-datasources-volume
        mountPath: "/etc/grafana/provisioning/datasources"
{{- end}}
{{- if .Values.sidecar.plugins.enabled }}
  - name: {{ template "grafana.name" . }}-sc-plugins
    {{- if .Values.sidecar.image.sha }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}@sha256:{{ .Values.sidecar.image.sha }}"
    {{- else }}
    image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}"
    {{- end }}
    imagePullPolicy: {{ .Values.sidecar.imagePullPolicy }}
    env:
      - name: METHOD
        value: {{ .Values.sidecar.plugins.watchMethod }}
      - name: LABEL
        value: "{{ .Values.sidecar.plugins.label }}"
      {{- if .Values.sidecar.plugins.labelValue }}
      - name: LABEL_VALUE
        value: {{ quote .Values.sidecar.plugins.labelValue }}
      {{- end }}
      - name: FOLDER
        value: "/etc/grafana/provisioning/plugins"
      - name: RESOURCE
        value: {{ quote .Values.sidecar.plugins.resource }}
      {{- if .Values.sidecar.enableUniqueFilenames }}
      - name: UNIQUE_FILENAMES
        value: "{{ .Values.sidecar.enableUniqueFilenames }}"
      {{- end }}
      {{- if .Values.sidecar.plugins.searchNamespace }}
      - name: NAMESPACE
        value: "{{ .Values.sidecar.plugins.searchNamespace | join "," }}"
      {{- end }}
      {{- if .Values.sidecar.skipTlsVerify }}
      - name: SKIP_TLS_VERIFY
        value: "{{ .Values.sidecar.skipTlsVerify }}"
      {{- end }}
      {{- if and (not .Values.env.GF_SECURITY_ADMIN_USER) (not .Values.env.GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION) }}
      - name: REQ_USERNAME
        valueFrom:
          secretKeyRef:
            name: {{ (tpl .Values.admin.existingSecret .) | default (include "grafana.fullname" .) }}
            key: {{ .Values.admin.userKey | default "admin-user" }}
      {{- end }}
      {{- if and (not .Values.env.GF_SECURITY_ADMIN_PASSWORD) (not .Values.env.GF_SECURITY_ADMIN_PASSWORD__FILE) (not .Values.env.GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION) }}
      - name: REQ_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ (tpl .Values.admin.existingSecret .) | default (include "grafana.fullname" .) }}
            key: {{ .Values.admin.passwordKey | default "admin-password" }}
      {{- end }}
      {{- if not .Values.sidecar.plugins.skipReload }}
      - name: REQ_URL
        value: {{ .Values.sidecar.plugins.reloadURL }}
      - name: REQ_METHOD
        value: POST
      {{- end }}
{{- if .Values.sidecar.livenessProbe }}
    livenessProbe:
{{ toYaml .Values.livenessProbe | indent 6 }}
{{- end }}
{{- if .Values.sidecar.readinessProbe }}
    readinessProbe:
{{ toYaml .Values.readinessProbe | indent 6 }}
{{- end }}
    resources:
{{ toYaml .Values.sidecar.resources | indent 6 }}
{{- if .Values.sidecar.securityContext }}
    securityContext:
{{- toYaml .Values.sidecar.securityContext | nindent 6 }}
{{- end }}
    volumeMounts:
      - name: sc-plugins-volume
        mountPath: "/etc/grafana/provisioning/plugins"
{{- end}}
  - name: {{ .Chart.Name }}
    {{- if .Values.image.sha }}
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}@sha256:{{ .Values.image.sha }}"
    {{- else }}
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
    {{- end }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
  {{- if .Values.command }}
    command:
    {{- range .Values.command }}
      - {{ . }}
    {{- end }}
  {{- end}}
{{- if .Values.containerSecurityContext }}
    securityContext:
{{- toYaml .Values.containerSecurityContext | nindent 6 }}
{{- end }}
    volumeMounts:
      - name: config
        mountPath: "/etc/grafana/grafana.ini"
        subPath: grafana.ini
      {{- if .Values.ldap.enabled }}
      - name: ldap
        mountPath: "/etc/grafana/ldap.toml"
        subPath: ldap.toml
      {{- end }}
      {{- $root := . }}
      {{- range .Values.extraConfigmapMounts }}
      - name: {{ tpl .name $root }}
        mountPath: {{ tpl .mountPath $root }}
        subPath: {{ (tpl .subPath $root) | default "" }}
        readOnly: {{ .readOnly }}
      {{- end }}
      - name: storage
        mountPath: "/var/lib/grafana"
{{- if .Values.persistence.subPath }}
        subPath: {{ tpl .Values.persistence.subPath . }}
{{- end }}
{{- if .Values.dashboards }}
{{- range $provider, $dashboards := .Values.dashboards }}
{{- range $key, $value := $dashboards }}
{{- if (or (hasKey $value "json") (hasKey $value "file")) }}
      - name: dashboards-{{ $provider }}
        mountPath: "/var/lib/grafana/dashboards/{{ $provider }}/{{ $key }}.json"
        subPath: "{{ $key }}.json"
{{- end }}
{{- end }}
{{- end }}
{{- end -}}
{{- if .Values.dashboardsConfigMaps }}
{{- range (keys .Values.dashboardsConfigMaps | sortAlpha) }}
      - name: dashboards-{{ . }}
        mountPath: "/var/lib/grafana/dashboards/{{ . }}"
{{- end }}
{{- end }}
{{- if .Values.datasources }}
{{- range (keys .Values.datasources | sortAlpha) }}
      - name: config
        mountPath: "/etc/grafana/provisioning/datasources/{{ . }}"
        subPath: {{ . | quote }}
{{- end }}
{{- end }}
{{- if .Values.notifiers }}
{{- range (keys .Values.notifiers | sortAlpha) }}
      - name: config
        mountPath: "/etc/grafana/provisioning/notifiers/{{ . }}"
        subPath: {{ . | quote }}
{{- end }}
{{- end }}
{{- if .Values.alerting }}
{{- range (keys .Values.alerting | sortAlpha) }}
      - name: config
        mountPath: "/etc/grafana/provisioning/alerting/{{ . }}"
        subPath: {{ . | quote }}
{{- end }}
{{- end }}
{{- if .Values.dashboardProviders }}
{{- range (keys .Values.dashboardProviders | sortAlpha) }}
      - name: config
        mountPath: "/etc/grafana/provisioning/dashboards/{{ . }}"
        subPath: {{ . | quote }}
{{- end }}
{{- end }}
{{- if .Values.sidecar.dashboards.enabled }}
      - name: sc-dashboard-volume
        mountPath: {{ .Values.sidecar.dashboards.folder | quote }}
{{ if .Values.sidecar.dashboards.SCProvider }}
      - name: sc-dashboard-provider
        mountPath: "/etc/grafana/provisioning/dashboards/sc-dashboardproviders.yaml"
        subPath: provider.yaml
{{- end}}
{{- end}}
{{- if .Values.sidecar.datasources.enabled }}
      - name: sc-datasources-volume
        mountPath: "/etc/grafana/provisioning/datasources"
{{- end}}
{{- if .Values.sidecar.plugins.enabled }}
      - name: sc-plugins-volume
        mountPath: "/etc/grafana/provisioning/plugins"
{{- end}}
{{- if .Values.sidecar.notifiers.enabled }}
      - name: sc-notifiers-volume
        mountPath: "/etc/grafana/provisioning/notifiers"
{{- end}}
    {{- range .Values.extraSecretMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: {{ .readOnly }}
        subPath: {{ .subPath | default "" }}
    {{- end }}
    {{- range .Values.extraVolumeMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        subPath: {{ .subPath | default "" }}
        readOnly: {{ .readOnly }}
    {{- end }}
    {{- range .Values.extraEmptyDirMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
    {{- end }}
    ports:
      - name: {{ .Values.podPortName }}
        containerPort: {{ .Values.service.targetPort }}
        protocol: TCP
    env:
      {{- if and (not .Values.env.GF_SECURITY_ADMIN_USER) (not .Values.env.GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION) }}
      - name: GF_SECURITY_ADMIN_USER
        valueFrom:
          secretKeyRef:
            name: {{ (tpl .Values.admin.existingSecret .) | default (include "grafana.fullname" .) }}
            key: {{ .Values.admin.userKey | default "admin-user" }}
      {{- end }}
      {{- if and (not .Values.env.GF_SECURITY_ADMIN_PASSWORD) (not .Values.env.GF_SECURITY_ADMIN_PASSWORD__FILE) (not .Values.env.GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION) }}
      - name: GF_SECURITY_ADMIN_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ (tpl .Values.admin.existingSecret .) | default (include "grafana.fullname" .) }}
            key: {{ .Values.admin.passwordKey | default "admin-password" }}
      {{- end }}
      {{- if .Values.plugins }}
      - name: GF_INSTALL_PLUGINS
        valueFrom:
          configMapKeyRef:
            name: {{ template "grafana.fullname" . }}
            key: plugins
      {{- end }}
      {{- if .Values.smtp.existingSecret }}
      - name: GF_SMTP_USER
        valueFrom:
          secretKeyRef:
            name: {{ .Values.smtp.existingSecret }}
            key: {{ .Values.smtp.userKey | default "user" }}
      - name: GF_SMTP_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ .Values.smtp.existingSecret }}
            key: {{ .Values.smtp.passwordKey | default "password" }}
      {{- end }}
      {{- if .Values.imageRenderer.enabled }}
      - name: GF_RENDERING_SERVER_URL
        value: http://{{ template "grafana.fullname" . }}-image-renderer.{{ template "grafana.namespace" . }}:{{ .Values.imageRenderer.service.port }}/render
      - name: GF_RENDERING_CALLBACK_URL
        value: {{ .Values.imageRenderer.grafanaProtocol }}://{{ template "grafana.fullname" . }}.{{ template "grafana.namespace" . }}:{{ .Values.service.port }}/{{ .Values.imageRenderer.grafanaSubPath }}
      {{- end }}
      - name: GF_PATHS_DATA
        value: {{ (get .Values "grafana.ini").paths.data }}
      - name: GF_PATHS_LOGS
        value: {{ (get .Values "grafana.ini").paths.logs }}
      - name: GF_PATHS_PLUGINS
        value: {{ (get .Values "grafana.ini").paths.plugins }}
      - name: GF_PATHS_PROVISIONING
        value: {{ (get .Values "grafana.ini").paths.provisioning }}
    {{- range $key, $value := .Values.envValueFrom }}
      - name: {{ $key | quote }}
        valueFrom:
{{ tpl (toYaml $value) $ | indent 10 }}
    {{- end }}
{{- range $key, $value := .Values.env }}
      - name: "{{ tpl $key $ }}"
        value: "{{ tpl (print $value) $ }}"
{{- end }}
    {{- if or .Values.envFromSecret (or .Values.envRenderSecret .Values.envFromSecrets) .Values.envFromConfigMaps }}
    envFrom:
    {{- if .Values.envFromSecret }}
      - secretRef:
          name: {{ tpl .Values.envFromSecret . }}
    {{- end }}
    {{- if .Values.envRenderSecret }}
      - secretRef:
          name: {{ template "grafana.fullname" . }}-env
    {{- end }}
    {{- range .Values.envFromSecrets }}
      - secretRef:
          name: {{ tpl .name $ }}
          optional: {{ .optional | default false }}
    {{- end }}
    {{- range .Values.envFromConfigMaps }}
      - configMapRef:
          name: {{ tpl .name $ }}
          optional: {{ .optional | default false }}
    {{- end }}
    {{- end }}
    livenessProbe:
{{ toYaml .Values.livenessProbe | indent 6 }}
    readinessProbe:
{{ toYaml .Values.readinessProbe | indent 6 }}
{{- if .Values.lifecycleHooks }}
    lifecycle: {{ tpl (.Values.lifecycleHooks | toYaml) . | nindent 6 }}
{{- end }}
    resources:
{{ toYaml .Values.resources | indent 6 }}
{{- with .Values.extraContainers }}
{{ tpl . $ | indent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
{{ toYaml . | indent 2 }}
{{- end }}
{{- $root := . }}
{{- with .Values.affinity }}
affinity:
{{ tpl (toYaml .) $root | indent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
{{ toYaml . | indent 2 }}
{{- end }}
volumes:
  - name: config
    configMap:
      name: {{ template "grafana.fullname" . }}
{{- $root := . }}
{{- range .Values.extraConfigmapMounts }}
  - name: {{ tpl .name $root }}
    configMap:
      name: {{ tpl .configMap $root }}
      {{- if .items }}
      items: {{ toYaml .items | nindent 6 }}
      {{- end }}
{{- end }}
  {{- if .Values.dashboards }}
    {{- range (keys .Values.dashboards | sortAlpha) }}
  - name: dashboards-{{ . }}
    configMap:
      name: {{ template "grafana.fullname" $ }}-dashboards-{{ . }}
    {{- end }}
  {{- end }}
  {{- if .Values.dashboardsConfigMaps }}
    {{ $root := . }}
    {{- range $provider, $name := .Values.dashboardsConfigMaps }}
  - name: dashboards-{{ $provider }}
    configMap:
      name: {{ tpl $name $root }}
    {{- end }}
  {{- end }}
  {{- if .Values.ldap.enabled }}
  - name: ldap
    secret:
      {{- if .Values.ldap.existingSecret }}
      secretName: {{ .Values.ldap.existingSecret }}
      {{- else }}
      secretName: {{ template "grafana.fullname" . }}
      {{- end }}
      items:
        - key: ldap-toml
          path: ldap.toml
  {{- end }}
{{- if and .Values.persistence.enabled (eq .Values.persistence.type "pvc") }}
  - name: storage
    persistentVolumeClaim:
      claimName: {{ tpl (.Values.persistence.existingClaim | default (include "grafana.fullname" .)) . }}
{{- else if and .Values.persistence.enabled (eq .Values.persistence.type "statefulset") }}
# nothing
{{- else }}
  - name: storage
{{- if .Values.persistence.inMemory.enabled }}
    emptyDir:
      medium: Memory
{{- if .Values.persistence.inMemory.sizeLimit }}
      sizeLimit: {{ .Values.persistence.inMemory.sizeLimit }}
{{- end -}}
{{- else }}
    emptyDir: {}
{{- end -}}
{{- end -}}
{{- if .Values.sidecar.dashboards.enabled }}
  - name: sc-dashboard-volume
{{- if .Values.sidecar.dashboards.sizeLimit }}
    emptyDir:
      sizeLimit: {{ .Values.sidecar.dashboards.sizeLimit }}
{{- else }}
    emptyDir: {}
{{- end -}}
{{- if .Values.sidecar.dashboards.SCProvider }}
  - name: sc-dashboard-provider
    configMap:
      name: {{ template "grafana.fullname" . }}-config-dashboards
{{- end }}
{{- end }}
{{- if .Values.sidecar.datasources.enabled }}
  - name: sc-datasources-volume
{{- if .Values.sidecar.datasources.sizeLimit }}
    emptyDir:
      sizeLimit: {{ .Values.sidecar.datasources.sizeLimit }}
{{- else }}
    emptyDir: {}
{{- end -}}
{{- end -}}
{{- if .Values.sidecar.plugins.enabled }}
  - name: sc-plugins-volume
{{- if .Values.sidecar.plugins.sizeLimit }}
    emptyDir:
      sizeLimit: {{ .Values.sidecar.plugins.sizeLimit }}
{{- else }}
    emptyDir: {}
{{- end -}}
{{- end -}}
{{- if .Values.sidecar.notifiers.enabled }}
  - name: sc-notifiers-volume
{{- if .Values.sidecar.notifiers.sizeLimit }}
    emptyDir:
      sizeLimit: {{ .Values.sidecar.notifiers.sizeLimit }}
{{- else }}
    emptyDir: {}
{{- end -}}
{{- end -}}
{{- range .Values.extraSecretMounts }}
{{- if .secretName }}
  - name: {{ .name }}
    secret:
      secretName: {{ .secretName }}
      defaultMode: {{ .defaultMode }}
      {{- if .items }}
      items: {{ toYaml .items | nindent 6 }}
      {{- end }}
{{- else if .projected }}
  - name: {{ .name }}
    projected: {{- toYaml .projected | nindent 6 }}
{{- else if .csi }}
  - name: {{ .name }}
    csi: {{- toYaml .csi | nindent 6 }}
{{- end }}
{{- end }}
{{- range .Values.extraVolumeMounts }}
  - name: {{ .name }}
    {{- if .existingClaim }}
    persistentVolumeClaim:
      claimName: {{ .existingClaim }}
    {{- else if .hostPath }}
    hostPath:
      path: {{ .hostPath }}
    {{- else }}
    emptyDir: {}
    {{- end }}
{{- end }}
{{- range .Values.extraEmptyDirMounts }}
  - name: {{ .name }}
    emptyDir: {}
{{- end -}}
{{- if .Values.extraContainerVolumes }}
{{ tpl (toYaml .Values.extraContainerVolumes) . | indent 2 }}
{{- end }}
{{- end }}
