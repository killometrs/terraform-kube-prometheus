#!/bin/bash
set -e

echo "=== Applying Manifests ==="

# Применяем Ingress Nginx
echo "Applying Ingress Nginx..."
kubectl apply -k manifests/ingress-nginx/

echo "Waiting for Ingress Nginx to be ready..."

# Ждем пока под ingress-nginx запустится (максимум 2 минуты)
echo "Waiting for ingress-nginx pod..."
timeout 120s bash -c 'until kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --field-selector=status.phase=Running --no-headers; do sleep 5; done'

# Проверяем что deployment готов
echo "Checking deployment status..."
kubectl wait --for=condition=available deployment/ingress-nginx-controller -n ingress-nginx --timeout=120s

echo "✅ Ingress Nginx is ready"

# Применяем остальные манифесты если есть
if [ -d "manifests/network-policies" ]; then
    echo "Applying Network Policies..."
    kubectl apply -k manifests/network-policies/
fi

if [ -d "manifests/ingress" ]; then
    echo "Applying Ingress resources..."
    kubectl apply -k manifests/ingress/
fi

echo "✅ All manifests applied successfully"
