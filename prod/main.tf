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
  storage_class_name = var.storage_class_name
  
  # Секреты
  grafana_admin_password = var.grafana_admin_password
  
  # Настройки мониторинга
  enable_alertmanager = true
  enable_thanos       = var.enable_thanos
  
  # Дополнительные values для Helm
  extra_values = var.extra_values
}
