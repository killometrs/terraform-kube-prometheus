grafana:
  admin:
    existingSecret: ""
    userKey: admin-user
    passwordKey: admin-password
  adminPassword: ${grafana_admin_password}
  persistence:
    enabled: true
    storageClassName: ${storage_class_name}
    size: 20Gi
  resources:
    limits:
      cpu: ${resource_limits.grafana.cpu}
      memory: ${resource_limits.grafana.memory}
    requests:
      cpu: 100m
      memory: 128Mi

prometheus:
  prometheusSpec:
    replicas: ${prometheus_replicas}
    retention: ${prometheus_retention}
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ${storage_class_name}
          resources:
            requests:
              storage: 100Gi
    resources:
      limits:
        cpu: ${resource_limits.prometheus.cpu}
        memory: ${resource_limits.prometheus.memory}
      requests:
        cpu: 500m
        memory: 1Gi

alertmanager:
  alertmanagerSpec:
    replicas: 3
    resources:
      limits:
        cpu: ${resource_limits.alertmanager.cpu}
        memory: ${resource_limits.alertmanager.memory}
      requests:
        cpu: 100m
        memory: 64Mi

thanosRuler:
  enabled: ${enable_thanos}

defaultRules:
  create: true
  rules:
    alertmanager: true
    etcd: true
    configReloaders: true
    general: true
    k8s: true
    kubeApiserver: true
    kubePrometheusGeneral: true
    kubePrometheusNodeRecording: true
    kubernetesApps: true
    kubernetesResources: true
    kubernetesStorage: true
    kubernetesSystem: true
    network: true
    node: true
    nodeExporterAlerting: true
    nodeExporterRecording: true
    prometheus: true
    prometheusOperator: true

kubeApiServer:
  enabled: true
kubelet:
  enabled: true
kubeControllerManager:
  enabled: true
coreDns:
  enabled: true
kubeEtcd:
  enabled: true
kubeScheduler:
  enabled: true
kubeProxy:
  enabled: true
kubeStateMetrics:
  enabled: true
nodeExporter:
  enabled: true
prometheusNodeExporter:
  enabled: true
