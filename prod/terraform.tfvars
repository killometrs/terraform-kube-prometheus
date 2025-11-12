# Публичные переменные
cluster_name = "production-k8s"
prometheus_stack_version = "58.2.0"
prometheus_replicas = 2
prometheus_retention = "5d"
enable_thanos = true
storage_class_name = "yc-network-hdd"

# Yandex Cloud настройки
yandex_zone = "ru-central1-a"

# Load Balancer аннотации
load_balancer_annotations = {
  "yandex.cloud/load-balancer-type" = "external"
}

# Дополнительные Helm values
extra_values = {
  "grafana.service.type" = "LoadBalancer"
  "grafana.service.annotations.yandex\\.cloud/load-balancer-type" = "external"
  
  "prometheus.service.type" = "LoadBalancer" 
  "prometheus.service.annotations.yandex\\.cloud/load-balancer-type" = "external"
  
  "alertmanager.service.type" = "LoadBalancer"
  "alertmanager.service.annotations.yandex\\.cloud/load-balancer-type" = "external"
  
  "grafana.persistence.enabled" = true
  "grafana.persistence.size" = "5Gi"
  "grafana.persistence.storageClassName" = "yc-network-hdd"
  
  "prometheus.prometheusSpec.replicas" = 2
  "prometheus.prometheusSpec.retention" = "2d"
  "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName" = "yc-network-hdd"
  "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage" = "5Gi"
  
  "alertmanager.alertmanagerSpec.replicas" = 1
  "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName" = "yc-network-hdd"
  "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage" = "5Gi"
}
