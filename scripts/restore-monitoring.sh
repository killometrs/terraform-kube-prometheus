 #!/bin/bash

echo "=== Starting Monitoring Restore ==="

# Настройки
BACKUP_DIR="./backup"

# Функция для поиска последнего бэкапа
find_latest_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        # Ищем любую директорию внутри backup (кроме . и ..)
        local latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "*" ! -name "." ! -name ".." | sort -r | head -1)
        
        if [ -n "$latest_backup" ] && [ "$latest_backup" != "$BACKUP_DIR" ]; then
            echo "$latest_backup"
            return 0
        else
            echo "No backup directories found in $BACKUP_DIR"
            return 1
        fi
    else
        echo "Backup directory $BACKUP_DIR does not exist"
        return 1
    fi
}

# Функция для безопасного применения ресурсов
safe_apply() {
    local file=$1
    if [ -f "$file" ] && [ -s "$file" ]; then
        echo "Applying $file..."
        kubectl apply -f "$file" --server-side=true --force-conflicts 2>/dev/null || \
        kubectl apply -f "$file" 2>/dev/null || echo "⚠️ Failed to apply $file"
    fi
}

# Поиск последнего бэкапа
echo "Looking for latest backup..."
RESTORE_DIR=$(find_latest_backup)

if [ -z "$RESTORE_DIR" ] || [ ! -d "$RESTORE_DIR" ]; then
    echo "❌ No valid backup found for restore"
    echo "Available backups in $BACKUP_DIR:"
    ls -la "$BACKUP_DIR" 2>/dev/null || echo "No backup directory"
    exit 1
fi

echo "Found backup: $RESTORE_DIR"

# Проверяем доступ к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

# Создаем namespace monitoring если не существует
if ! kubectl get namespace monitoring &> /dev/null; then
    echo "Creating monitoring namespace..."
    kubectl create namespace monitoring
fi

# Восстанавливаем ресурсы в правильном порядке
echo "Restoring monitoring resources..."

# Проверяем что есть файлы для восстановления
if [ ! -f "$RESTORE_DIR/all-resources.yaml" ] && [ ! -f "$RESTORE_DIR/resources.yaml" ]; then
    echo "ℹ️ No standard backup files found, checking for any YAML files..."
    
    # Ищем любые YAML файлы
    yaml_files=$(find "$RESTORE_DIR" -name "*.yaml" -o -name "*.yml")
    if [ -z "$yaml_files" ]; then
        echo "❌ No YAML files found in backup directory"
        echo "Backup contents:"
        ls -la "$RESTORE_DIR"
        exit 1
    fi
fi

# 1. Восстанавливаем базовые ресурсы
if [ -f "$RESTORE_DIR/all-resources.yaml" ]; then
    echo "Restoring all resources..."
    safe_apply "$RESTORE_DIR/all-resources.yaml"
elif [ -f "$RESTORE_DIR/resources.yaml" ]; then
    echo "Restoring resources..."
    safe_apply "$RESTORE_DIR/resources.yaml"
fi

# 2. Восстанавливаем отдельные ресурсы по типам
for resource_file in "$RESTORE_DIR"/*.yaml "$RESTORE_DIR"/*.yml; do
    if [ -f "$resource_file" ]; then
        filename=$(basename "$resource_file")
        case "$filename" in
            "all-resources.yaml"|"resources.yaml")
                # Уже применили
                ;;
            "grafana-deployment.yaml")
                echo "Restoring Grafana deployment..."
                safe_apply "$resource_file"
                ;;
            "configmaps.yaml")
                echo "Restoring configmaps..."
                safe_apply "$resource_file"
                ;;
            "pvc.yaml")
                echo "Restoring PVCs..."
                safe_apply "$resource_file"
                ;;
            "secrets.yaml")
                echo "Restoring secrets..."
                safe_apply "$resource_file"
                ;;
            "serviceaccounts.yaml")
                echo "Restoring service accounts..."
                safe_apply "$resource_file"
                ;;
            *)
                echo "Applying $filename..."
                safe_apply "$resource_file"
                ;;
        esac
    fi
done

echo "✅ Restore completed from: $RESTORE_DIR"

# Проверяем статус восстановления
echo "=== Restore Status ==="
kubectl get all -n monitoring 2>/dev/null || echo "No resources in monitoring namespace"

echo "=== Restore Process Finished ==="
