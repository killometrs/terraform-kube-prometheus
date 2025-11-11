# Основные выходные данные
output "namespace" {
  description = "Monitoring namespace name"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.kube_prometheus_stack.name
}

output "release_version" {
  description = "Helm release version"
  value       = helm_release.kube_prometheus_stack.version
}

output "release_status" {
  description = "Helm release status"
  value       = helm_release.kube_prometheus_stack.status
}

# Endpoints
output "prometheus_service_name" {
  description = "Prometheus service name"
  value       = "prometheus-operated"
}

output "prometheus_service_port" {
  description = "Prometheus service port"
  value       = 9090
}

output "alertmanager_service_name" {
  description = "Alertmanager service name"
  value       = "alertmanager-operated"
}

output "alertmanager_service_port" {
  description = "Alertmanager service port"
  value       = 9093
}

output "grafana_service_name" {
  description = "Grafana service name"
  value       = "${helm_release.kube_prometheus_stack.name}-grafana"
}

output "grafana_service_port" {
  description = "Grafana service port"
  value       = 80
}

# URLs
output "prometheus_url" {
  description = "Prometheus UI URL"
  value       = "http://prometheus-operated.monitoring.svc.cluster.local:9090"
}

output "alertmanager_url" {
  description = "Alertmanager UI URL"
  value       = "http://alertmanager-operated.monitoring.svc.cluster.local:9093"
}

output "grafana_url" {
  description = "Grafana UI URL"
  value       = "http://${helm_release.kube_prometheus_stack.name}-grafana.monitoring.svc.cluster.local"
}

# Данные для подключения
output "kube_prometheus_stack_values" {
  description = "Values used for kube-prometheus-stack"
  value       = helm_release.kube_prometheus_stack.values
  sensitive   = true
}

# Информация о ресурсах
output "deployed_resources" {
  description = "Map of deployed resources"
  value = {
    namespace        = kubernetes_namespace.monitoring.metadata[0].name
    prometheus_replicas = var.prometheus_replicas
    retention        = var.prometheus_retention
    storage_class    = var.storage_class_name
    enable_thanos    = var.enable_thanos
  }
}

# Команды для проверки
output "verification_commands" {
  description = "Commands to verify the deployment"
  value = {
    check_pods = "kubectl get pods -n monitoring"
    check_services = "kubectl get svc -n monitoring"
    check_pvc = "kubectl get pvc -n monitoring"
    grafana_password = "kubectl get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 --decode"
  }
  sensitive = true
}
