# Основные параметры
variable "cluster_name" {
  type        = string
  description = "Name of the Kubernetes cluster"
}

variable "environment" {
  type        = string
  description = "Environment name (prod)"
  validation {
    condition     = contains(["prod"], var.environment)
    error_message = "Environment must be 'prod'."
  }
}

# Версии чартов
variable "prometheus_stack_version" {
  type        = string
  description = "Version of kube-prometheus-stack Helm chart"
  default     = "79.5.0"
}

# Ресурсы и масштабирование
variable "prometheus_replicas" {
  type        = number
  description = "Number of Prometheus replicas"
  default     = 2
}

variable "prometheus_retention" {
  type        = string
  description = "Prometheus data retention period"
  default     = "30d"
}

# Секреты
variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
}

# Флаги функций
variable "enable_alertmanager" {
  type        = bool
  description = "Enable Alertmanager"
  default     = true
}

variable "enable_thanos" {
  type        = bool
  description = "Enable Thanos for long-term storage"
  default     = false
}


# Yandex Cloud специфичные
variable "load_balancer_annotations" {
  type        = map(string)
  description = "Annotations for LoadBalancer services"
  default     = {}
}

variable "network_policy_enabled" {
  type        = bool
  description = "Enable network policies for Yandex Cloud"
  default     = true
}

# Дополнительные настройки Helm
variable "extra_values" {
  type        = map(any)
  description = "Extra values to pass to Helm chart"
  default     = {}
}

# Node selector и tolerations
variable "node_selector" {
  type        = map(string)
  description = "Node selector for monitoring components"
  default     = {}
}

variable "tolerations" {
  type = list(object({
    key      = string
    operator = string
    value    = optional(string)
    effect   = string
  }))
  description = "Tolerations for monitoring components"
  default     = []
}

# Resource limits
variable "resource_limits" {
  type = object({
    prometheus = object({
      cpu    = string
      memory = string
    })
    grafana = object({
      cpu    = string
      memory = string
    })
    alertmanager = object({
      cpu    = string
      memory = string
    })
  })
  description = "Resource limits for monitoring components"
  default = {
    prometheus = {
      cpu    = "1000m"
      memory = "2Gi"
    }
    grafana = {
      cpu    = "500m"
      memory = "1Gi"
    }
    alertmanager = {
      cpu    = "200m"
      memory = "512Mi"
    }
  }
}

# Ingress settings
variable "enable_ingress" {
  type        = bool
  description = "Enable Ingress resources for monitoring stack"
  default     = false
}

variable "ingress_class_name" {
  type        = string
  description = "Ingress class name"
  default     = "nginx"
}

variable "enable_network_policies" {
  type        = bool
  description = "Enable network policies for monitoring components"
  default     = true
}

variable "storage_class_name" {
  description = "Name of the storage class to use for persistence"
  type        = string
  default     = "standard"
}
