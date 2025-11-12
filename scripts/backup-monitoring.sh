#!/bin/bash
set -e

echo "=== Starting Monitoring Backup ==="
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# Бэкап Grafana
echo "Backing up Grafana..."
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 &
GRAFANA_PID=$!
sleep 5

# Бэкап дашбордов
curl -s -u "admin:$GRAFANA_PASSWORD" http://localhost:3000/api/search?type=dash-db | jq -r '.[] | .uid' | while read uid; do
    curl -s -u "admin:$GRAFANA_PASSWORD" "http://localhost:3000/api/dashboards/uid/$uid" > "$BACKUP_DIR/grafana-dashboard-$uid.json"
    echo "Backed up dashboard: $uid"
done

# Бэкап datasources
curl -s -u "admin:$GRAFANA_PASSWORD" http://localhost:3000/api/datasources > "$BACKUP_DIR/grafana-datasources.json"

# Бэкап alert rules
kubectl get prometheusrules -n monitoring -o yaml > "$BACKUP_DIR/prometheus-rules.yaml"

# Бэкап PVC данных (метрики Prometheus и Grafana)
echo "Backing up PVC data..."
kubectl get pvc -n monitoring -o name | while read pvc; do
    PVC_NAME=$(echo $pvc | cut -d'/' -f2)
    kubectl exec -n monitoring deployment/kube-prometheus-stack-prometheus -- tar czf - /prometheus > "$BACKUP_DIR/prometheus-data-$PVC_NAME.tar.gz" 2>/dev/null || true
    kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- tar czf - /var/lib/grafana > "$BACKUP_DIR/grafana-data-$PVC_NAME.tar.gz" 2>/dev/null || true
done

kill $GRAFANA_PID

# Бэкап конфигов
kubectl get configmaps -n monitoring -l release=kube-prometheus-stack -o yaml > "$BACKUP_DIR/configmaps.yaml"
kubectl get secrets -n monitoring -l release=kube-prometheus-stack -o yaml > "$BACKUP_DIR/secrets.yaml"

echo "=== Backup completed: $BACKUP_DIR ==="
ls -la $BACKUP_DIR/
