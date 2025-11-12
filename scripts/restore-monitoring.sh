#!/bin/bash
set -e

BACKUP_DIR=${1:-"backup-latest"}

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory $BACKUP_DIR not found!"
    exit 1
fi

echo "=== Starting Monitoring Restore from $BACKUP_DIR ==="

# Восстановление Grafana дашбордов
echo "Restoring Grafana dashboards..."
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 &
GRAFANA_PID=$!
sleep 5

for dashboard_file in $BACKUP_DIR/grafana-dashboard-*.json; do
    if [ -f "$dashboard_file" ]; then
        curl -s -X POST -u "admin:$GRAFANA_PASSWORD" -H "Content-Type: application/json" \
             http://localhost:3000/api/dashboards/db -d @"$dashboard_file"
        echo "Restored dashboard: $dashboard_file"
    fi
done

# Восстановление datasources
if [ -f "$BACKUP_DIR/grafana-datasources.json" ]; then
    cat "$BACKUP_DIR/grafana-datasources.json" | jq -c '.[]' | while read datasource; do
        curl -s -X POST -u "admin:$GRAFANA_PASSWORD" -H "Content-Type: application/json" \
             http://localhost:3000/api/datasources -d "$datasource"
    done
fi

kill $GRAFANA_PID

# Восстановление Prometheus rules
if [ -f "$BACKUP_DIR/prometheus-rules.yaml" ]; then
    kubectl apply -f "$BACKUP_DIR/prometheus-rules.yaml"
fi

# Восстановление данных PVC (требует остановки пода)
echo "Restoring PVC data..."
for data_file in $BACKUP_DIR/prometheus-data-*.tar.gz; do
    if [ -f "$data_file" ]; then
        PVC_NAME=$(echo $data_file | sed 's/.*prometheus-data-//' | sed 's/.tar.gz//')
        echo "Restoring Prometheus data to PVC: $PVC_NAME"
        # Здесь нужна сложная логика восстановления данных
    fi
done

echo "=== Restore completed ==="
