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
    exit 1
fi

echo "Checking monitoring namespace resources..."
kubectl get all -n "$GRAFANA_NAMESPACE"

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
    
    return 1
}

# Поиск Grafana deployment
GRAFANA_DEPLOYMENT=$(find_grafana_deployment)

if [ -z "$GRAFANA_DEPLOYMENT" ]; then
    echo "Grafana deployment not found in namespace '$GRAFANA_NAMESPACE'"
    echo "Available deployments:"
    kubectl get deployments -n "$GRAFANA_NAMESPACE" 2>/dev/null || echo "No deployments found"
    
    echo "Creating basic backup of namespace resources..."
else
    echo "Backing up Grafana deployment: $GRAFANA_DEPLOYMENT"
    kubectl get deployment "$GRAFANA_DEPLOYMENT" -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/grafana-deployment.yaml"
fi

# Бэкап всех ресурсов в неймспейсе monitoring
echo "Backing up all monitoring resources..."

# Бэкап основных ресурсов
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

echo "✓ All resources backed up to $BACKUP_DIR"

# Проверяем статус Grafana если нашли
if [ -n "$GRAFANA_DEPLOYMENT" ]; then
    GRAFANA_STATUS=$(kubectl get deployment "$GRAFANA_DEPLOYMENT" -n "$GRAFANA_NAMESPACE" -o jsonpath='{.status.readyReplicas}')
    GRAFANA_POD=$(kubectl get pods -n "$GRAFANA_NAMESPACE" -l "app.kubernetes.io/name=grafana" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ "$GRAFANA_STATUS" = "1" ] && [ -n "$GRAFANA_POD" ]; then
        echo "✅ Grafana is running, pod: $GRAFANA_POD"
        echo "Attempting data backup..."
        
        # Бэкап данных Grafana если запущена
        kubectl exec -n "$GRAFANA_NAMESPACE" "$GRAFANA_POD" -- tar czf - /var/lib/grafana > "$BACKUP_DIR/grafana-data.tar.gz" 2>/dev/null || echo "⚠️ Could not backup Grafana data"
    else
        echo "⚠️ Grafana is not running (ready replicas: ${GRAFANA_STATUS:-0})"
    fi
fi

echo "=== Backup Summary ==="
echo "Backup location: $BACKUP_DIR"
ls -la "$BACKUP_DIR"
echo "====================="
