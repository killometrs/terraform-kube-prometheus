#!/bin/bash

set -e

echo "Applying Ingress Nginx..."
kubectl apply -k manifests/ingress-nginx/

echo "Waiting for Ingress Nginx to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "Restarting Ingress Nginx deployment..."
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller

echo "Waiting for rollout to complete..."
kubectl rollout status deployment -n ingress-nginx ingress-nginx-controller --timeout=300s

echo "Applying network policies..."
kubectl apply -k manifests/network-policies/

echo "Applying ingress resources..."
kubectl apply -k manifests/ingress/

echo "All manifests applied successfully!"
