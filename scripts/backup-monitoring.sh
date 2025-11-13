#!/bin/bash

echo "=== Starting Monitoring Backup ==="

# Настройки
GRAFANA_NAMESPACE="monitoring"
BACKUP_DIR="./backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Функция для безопасного выполнения команд
safe_run() {
    "$@" 2>/dev/null || true
}

# Проверяем что неймспейс monitoring существует
if ! kubectl get namespace "$GRAFANA_NAMESPACE" &> /dev/null; then
    echo "Namespace '$GRAFANA_NAMESPACE' does not exist"
    echo "Available namespaces:"
    safe_run kubectl get namespaces
    echo "No monitoring resources to backup"
    echo "✅ Backup process completed (no namespace)"
    exit 0
fi

echo "Namespace '$GRAFANA_NAMESPACE' exists"

# Проверяем ресурсы без вывода ошибок
echo "Checking resources..."
RESOURCES=$(safe_run kubectl get all -n "$GRAFANA_NAMESPACE")

if [ -z "$RESOURCES" ] || echo "$RESOURCES" | grep -q "No resources found"; then
    echo "No resources found in monitoring namespace"
    echo "Creating empty backup..."
else
    echo "Resources found:"
    echo "$RESOURCES"
fi

# Бэкап всех ресурсов в неймспейсе monitoring (игнорируем ошибки)
echo "Backing up monitoring resources..."

# Бэкап основных ресурсов
safe_run kubectl get all -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/all-resources.yaml"
safe_run kubectl get configmaps -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/configmaps.yaml"
safe_run kubectl get secrets -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/secrets.yaml"
safe_run kubectl get pvc -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/pvc.yaml"
safe_run kubectl get serviceaccount -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/serviceaccounts.yaml"

# Бэкап CRD если есть
safe_run kubectl get servicemonitors -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/servicemonitors.yaml"
safe_run kubectl get prometheuses -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/prometheuses.yaml"
safe_run kubectl get alertmanagers -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/alertmanagers.yaml"

# Проверяем есть ли Grafana
GRAFANA_DEPLOYMENT=$(safe_run kubectl get deployment -n "$GRAFANA_NAMESPACE" -l "app.kubernetes.io/name=grafana" -o jsonpath='{.items[0].metadata.name}')
if [ -n "$GRAFANA_DEPLOYMENT" ]; then
    echo "Found Grafana deployment: $GRAFANA_DEPLOYMENT"
    safe_run kubectl get deployment "$GRAFANA_DEPLOYMENT" -n "$GRAFANA_NAMESPACE" -o yaml > "$BACKUP_DIR/grafana-deployment.yaml"
fi

# Создаем файл с информацией о бэкапе
echo "Backup created at: $(date)" > "$BACKUP_DIR/backup-info.txt"
echo "Namespace: $GRAFANA_NAMESPACE" >> "$BACKUP_DIR/backup-info.txt"
echo "Resources found: $(find "$BACKUP_DIR" -name "*.yaml" -exec grep -l "apiVersion" {} \; | wc -l)" >> "$BACKUP_DIR/backup-info.txt"

echo "✅ Backup completed: $BACKUP_DIR"
echo "Backup contents:"
ls -la "$BACKUP_DIR"

echo "=== Backup Process Finished Successfully ==="
exit 0
