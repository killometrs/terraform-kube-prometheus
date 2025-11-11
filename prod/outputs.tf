output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring"
  value       = module.kube_prometheus.namespace
}

output "grafana_url" {
  description = "Grafana service URL"
  value       = module.kube_prometheus.grafana_url
}

output "prometheus_url" {
  description = "Prometheus service URL"
  value       = module.kube_prometheus.prometheus_url
}

output "alertmanager_url" {
  description = "Alertmanager service URL"
  value       = module.kube_prometheus.alertmanager_url
}

output "deployment_commands" {
  description = "Commands to verify deployment"
  value       = module.kube_prometheus.verification_commands
  sensitive   = true
}
