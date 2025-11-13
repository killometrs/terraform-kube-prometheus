# Создание namespace для мониторинга
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name        = "monitoring"
      environment = var.environment
      cluster     = var.cluster_name
    }
  }
}

# Создание секрета для Grafana
resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin-credentials"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    admin-user     = "admin"
    admin-password = var.grafana_admin_password
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Network Policy для изоляции
resource "kubernetes_network_policy" "monitoring_isolate" {
  count = var.network_policy_enabled ? 1 : 0
  
  metadata {
    name      = "monitoring-isolate"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "monitoring"
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "monitoring"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}


# Установка kube-prometheus stack
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "58.2.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  disable_webhooks = true
  force_update    = true
  cleanup_on_fail = true
  replace         = true
  wait       = false

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      grafana_admin_password = var.grafana_admin_password
      prometheus_replicas    = var.prometheus_replicas
      prometheus_retention   = var.prometheus_retention
      storage_class_name     = var.storage_class_name  # ← ИЗМЕНИТЬ НА storage_class
      enable_thanos          = var.enable_thanos
      resource_limits        = var.resource_limits
    })
  ]

  dynamic "set" {
    for_each = var.extra_values
    content {
      name  = set.key
      value = set.value
    }
  }

  dynamic "set" {
    for_each = var.node_selector
    content {
      name  = "nodeSelector.${set.key}"
      value = set.value
    }
  }

  set {
    name  = "grafana.admin.existingSecret"
    value = kubernetes_secret.grafana_admin.metadata[0].name
  }

  set {
    name  = "alertmanager.enabled"
    value = var.enable_alertmanager
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_secret.grafana_admin
  ]

  lifecycle {
    create_before_destroy = true
  }
}
# Ingress для Grafana
resource "kubernetes_ingress_v1" "grafana" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target"    = "/"
      "nginx.ingress.kubernetes.io/proxy-body-size"   = "100m"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name
    
    rule {
      http {
        path {
          path = "/"
          backend {
            service {
              name = "${helm_release.kube_prometheus_stack.name}-grafana"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# Network Policy для Grafana
resource "kubernetes_network_policy" "grafana" {
  count = var.enable_network_policies ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "grafana"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      ports {
        port     = "3000"
        protocol = "TCP"
      }
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
