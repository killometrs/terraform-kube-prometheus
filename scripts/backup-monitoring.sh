#!/bin/bash
set -e

echo "=== Starting Monitoring Backup ==="

# Настройки
GRAFANA_NAMESPACE="monitoring"
GRAFANA_DEPLOYMENT="kube-prometheus-stack-grafana"

# Проверяем что неймспейс monitoring существует
if ! kubectl get namespace "$GRAFANA_NAMESPACE" &> /dev/null; then
    echo "Namespace '$GRAFANA_NAMESPACE' does not exist"
    exit 1
fi

# Проверяем что Grafana deployment существует
if ! kubectl get deployment "$GRAFANA_DEPLOYMENT" -n "$GRAFANA_NAMESPACE" &> /dev/null; then
    echo "Grafana deployment '$GRAFANA_DEPLOYMENT' not found in namespace '$GRAFANA_NAMESPACE'"
    echo "Available deployments in $GRAFANA_NAMESPACE:"
    kubectl get deployments -n "$GRAFANA_NAMESPACE"
    exit 1
fi

# Проверяем статус Grafana
echo "Checking Grafana status..."
GRAFANA_STATUS=$(kubectl get deployment "$GRAFANA_DEPLOYMENT" -n "$GRAFANA_NAMESPACE" -o jsonpath='{.status.readyReplicas}')
GRAFANA_POD=$(kubectl get pods -n "$GRAFANA_NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ "$GRAFANA_STATUS" != "1" ]; then
    echo "⚠️  Grafana is not ready. Current ready replicas: ${GRAFANA_STATUS:-0}"
    echo "Pod status:"
    kubectl get pods -n "$GRAFANA_NAMESPACE" -l app.kubernetes.io/name=grafana
    
    if [ -n "$GRAFANA_POD" ]; then
        echo "Pod details:"
        kubectl describe pod "$GRAFANA_POD" -n "$GRAFANA_NAMESPACE" | grep -A 10 "Status:"
        echo "Recent logs:"
        kubectl logs "$GRAFANA_POD" -n "$GRAFANA_NAMESPACE" --tail=20 || true
    fi
    
    echo "Attempting backup anyway..."
fi

echo "Backing up Grafana from deployment: $GRAFANA_DEPLOYMENT"

# Создаем директорию для бэкапа
BACKUP_DIR="./backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Бэкап ресурсов Kubernetes
echo "Backing up Kubernetes resources..."
kubectl get deployment "$GRAFANA_DEPLOYMENT" -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/grafana-deployment.yaml"
kubectl get configmaps -n "$GRAFANA_NAMESPACE" -l app.kubernetes.io/name=grafana -o yaml > "$BACKUP_DIR/grafana-configmaps.yaml" 2>/dev/null || true
kubectl get secrets -n "$GRAFANA_NAMESPACE" -l app.kubernetes.io/name=grafana -o yaml > "$BACKUP_DIR/grafana-secrets.yaml" 2>/dev/null || true
kubectl get pvc -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/grafana-pvc.yaml" 2>/dev/null || true

echo "✓ Kubernetes resources backed up to $BACKUP_DIR"

# Если под запущен, пробуем сделать бэкап данных
if [ -n "$GRAFANA_POD" ] && kubectl get pod "$GRAFANA_POD" -n "$GRAFANA_NAMESPACE" -o jsonpath='{.status.phase}' | grep -q Running; then
    echo "Backing up Grafana data..."
    
    # Бэкап через port-forward (если нужен доступ к API)
    echo "Starting port-forward for Grafana API..."
    kubectl port-forward "$GRAFANA_POD" -n "$GRAFANA_NAMESPACE" 3000:3000 &
    PF_PID=$!
    sleep 5
    
    # Попробовать экспорт через API или копирование файлов
    echo "Attempting data export..."
    # Добавьте вашу логику экспорта данных здесь
    
    kill $PF_PID 2>/dev/null
    echo "✓ Grafana data backup attempted"
else
    echo "⚠️  Skipping data backup - Grafana pod not running"
fi

echo "=== Backup completed ==="
ls -la "$BACKUP_DIR"
