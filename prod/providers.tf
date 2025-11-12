terraform {
  required_version = ">= 1.5.0"
  
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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  backend "s3" {
    # Конфигурация через backend.conf
  }
}

provider "yandex" {
  cloud_id  = var.yandex_cloud_id
  folder_id = var.yandex_folder_id
  zone      = var.yandex_zone
}

provider "kubernetes" {
  config_path = "/home/runner/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "/home/runner/.kube/config"
  }
}

provider "kubectl" {
  config_path = "/home/runner/.kube/config"
}
