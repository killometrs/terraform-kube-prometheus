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
  load_balancer_annotations = var.load_balancer_annotations

  # Секреты
  grafana_admin_password = var.grafana_admin_password

  # Настройки мониторинга
  enable_alertmanager = true
  enable_thanos       = var.enable_thanos

  # *** ИСПРАВЛЕННАЯ ЧАСТЬ: Передача структурированных значений Helm ***

  # Удаляем extra_values и передаем сложный объект в новую переменную values
  values = {
    grafana = {
      service = {
        type        = "LoadBalancer"
        annotations = var.load_balancer_annotations
      }
    }
    prometheus = {
      service = {
        type        = "LoadBalancer"
        annotations = var.load_balancer_annotations
      }
    }
    alertmanager = {
      service = {
        type        = "LoadBalancer"
        annotations = var.load_balancer_annotations
      }
    }
  }

  # Если вы используете node_selector, его тоже нужно передать структурированно:
  # node_selector = var.node_selector # Предполагая, что var.node_selector определен в prod/variables.tf
}
