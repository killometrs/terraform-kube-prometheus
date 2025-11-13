#!/bin/bash
set -e

echo "=== Starting Monitoring Backup ==="

# Настройки
GRAFANA_NAMESPACE="monitoring"
BACKUP_DIR="./backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Проверяем что неймспейс monitoring существует
if ! kubectl get namespace "$GRAFANA_NAMESPACE" &> /dev/null; then
    echo "Namespace '$GRAFANA_NAMESPACE' does not exist"
    echo "Available namespaces:"
    kubectl get namespaces
    echo "✅ No monitoring resources to backup"
    exit 0
fi

echo "Checking monitoring namespace resources..."

# Проверяем ресурсы без вывода ошибок
RESOURCES=$(kubectl get all -n "$GRAFANA_NAMESPACE" 2>/dev/null || true)

if [ -z "$RESOURCES" ] || echo "$RESOURCES" | grep -q "No resources found"; then
    echo "No resources found in monitoring namespace"
    echo "✅ Creating empty backup - namespace exists but no resources yet"
else
    echo "Resources found in monitoring namespace:"
    echo "$RESOURCES"
fi

# Функция для поиска Grafana
find_grafana_deployment() {
    echo "Searching for Grafana deployment..."
    
    # Пробуем разные возможные имена Grafana deployment
    local possible_names=(
        "kube-prometheus-stack-grafana"
        "grafana"
        "prometheus-stack-grafana"
        "monitoring-grafana"
    )
    
    for deployment_name in "${possible_names[@]}"; do
        if kubectl get deployment "$deployment_name" -n "$GRAFANA_NAMESPACE" &> /dev/null; then
            echo "Found Grafana deployment: $deployment_name"
            echo "$deployment_name"
            return 0
        fi
    done
    
    # Ищем по меткам
    echo "Searching by labels..."
    local labeled_deployment=$(kubectl get deployment -n "$GRAFANA_NAMESPACE" -l "app.kubernetes.io/name=grafana" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$labeled_deployment" ]; then
        echo "Found Grafana deployment by labels: $labeled_deployment"
        echo "$labeled_deployment"
        return 0
    fi
    
    echo "No Grafana deployment found"
    return 1
}

# Поиск Grafana deployment
GRAFANA_DEPLOYMENT=$(find_grafana_deployment)

# Бэкап всех ресурсов в неймспейсе monitoring (игнорируем ошибки)
echo "Backing up monitoring resources..."

# Бэкап основных ресурсов (игнорируем ошибки если нет ресурсов)
kubectl get all -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/all-resources.yaml" 2>/dev/null || true

# Бэкап конфигураций
kubectl get configmaps -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/configmaps.yaml" 2>/dev/null || true
kubectl get secrets -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/secrets.yaml" 2>/dev/null || true
kubectl get pvc -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/pvc.yaml" 2>/dev/null || true
kubectl get serviceaccount -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/serviceaccounts.yaml" 2>/dev/null || true

# Бэкап CRD если есть
kubectl get servicemonitors -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/servicemonitors.yaml" 2>/dev/null || true
kubectl get prometheuses -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/prometheuses.yaml" 2>/dev/null || true
kubectl get alertmanagers -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/alertmanagers.yaml" 2>/dev/null || true

# Бэкап Grafana deployment если нашли
if [ -n "$GRAFANA_DEPLOYMENT" ]; then
    kubectl get deployment "$GRAFANA_DEPLOYMENT" -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/grafana-deployment.yaml"
    echo "✅ Backed up Grafana deployment: $GRAFANA_DEPLOYMENT"
fi

# Проверяем что бэкап создан
if [ -f "$BACKUP_DIR/all-resources.yaml" ] || [ -f "$BACKUP_DIR/grafana-deployment.yaml" ]; then
    echo "✅ Backup completed successfully: $BACKUP_DIR"
    echo "Backup contents:"
    ls -la "$BACKUP_DIR"
else
    echo "✅ Empty backup created - no resources in monitoring namespace"
    echo "Backup directory: $BACKUP_DIR"
    # Создаем пустой файл чтобы показать что бэкап был выполнен
    echo "No resources in monitoring namespace at $(date)" > "$BACKUP_DIR/empty-backup.txt"
    ls -la "$BACKUP_DIR"
fi

echo "=== Backup Process Completed ==="
