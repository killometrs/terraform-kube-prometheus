
# StorageClass для всего кластера
resource "kubernetes_storage_class_v1" "cluster_storage" {
  metadata {
    name = "standard"
  }
  
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "WaitForFirstConsumer"
  reclaim_policy      = "Retain"
}


module "kube_prometheus" {
  source = "../modules/kube-prometheus"


  # Основные параметры
  cluster_name     = var.cluster_name
  environment      = "prod"
  
  # Версии
  prometheus_stack_version = var.prometheus_stack_version
  
  # Ресурсы
  prometheus_replicas = var.prometheus_replicas
  prometheus_retention = var.prometheus_retention
  
  # Yandex Cloud специфичные настройки
  storage_class_name = "standard"
  
  # Секреты
  grafana_admin_password = var.grafana_admin_password
  
  # Настройки мониторинга
  enable_alertmanager = true
  enable_thanos       = var.enable_thanos
  
  # Дополнительные values для Helm
  extra_values = var.extra_values
}
