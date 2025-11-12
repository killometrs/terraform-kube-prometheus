terraform {
  # Добавьте этот блок в начало файла modules/kube-prometheus/main.tf
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.95"
    }
    # Укажите, что модуль тоже использует gavinbunney/kubectl
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

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


# --- ДОБАВЛЕННЫЙ РЕСУРС: Установка ServiceMonitor CRD ---
resource "kubectl_manifest" "prometheus_self_monitor_crd" {
  yaml_body = file("${path.module}/crd-servicemonitors.yaml")
}

# --- ДОБАВЛЕННЫЙ РЕСУРС: Задержка для применения CRD ---
resource "time_sleep" "wait_for_crd" {
  depends_on = [kubectl_manifest.prometheus_self_monitor_crd]
  # Ждем 5 секунд, этого обычно достаточно
  create_duration = "5s" 
}


# Установка kube-prometheus stack
resource "helm_release" "kube_prometheus_stack" {
  

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600
  wait       = true
  
  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      grafana_admin_password = var.grafana_admin_password
      prometheus_replicas    = var.prometheus_replicas
      prometheus_retention   = var.prometheus_retention
      storage_class_name     = var.storage_class_name
      enable_thanos          = var.enable_thanos
      resource_limits        = var.resource_limits
    }),
    yamlencode(var.values)
  ]
  

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
    kubernetes_secret.grafana_admin,
    kubectl_manifest.prometheus_self_monitor_crd,
    time_sleep.wait_for_crd
  ]

  lifecycle {
    create_before_destroy = true
  }
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

# ServiceMonitor для самого Prometheus
resource "kubernetes_manifest" "prometheus_self_monitor" {
  provider = kubernetes
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "prometheus-self-monitor"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        release = helm_release.kube_prometheus_stack.name
      }
    }
    spec = {
      selector = {
        matchLabels = {
          operated-prometheus = "true"
        }
      }
      endpoints = [{
        port     = "web"
        interval = "30s"
        path     = "/metrics"
      }]
    }
  }
  depends_on = [
    helm_release.kube_prometheus_stack,
  ]
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
#      from = []
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
