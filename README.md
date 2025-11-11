# Kube-Prometheus Stack Automation

Автоматическое развертывание kube-prometheus в Yandex Cloud Kubernetes с использованием Atlantis.

## Secrets Required in GitHub:
- `YC_TOKEN` - Yandex Cloud OAuth или IAM токен
- `YC_CLOUD_ID` - ID облака
- `YC_FOLDER_ID` - ID folder
- `YC_ACCESS_KEY` - Static key для S3
- `YC_SECRET_KEY` - Secret key для S3  
- `YC_S3_BUCKET` - Имя бакета для state
- `YC_S3_STATE_KEY` - Ключ для state файла
- `KUBE_CONFIG_DATA` - kubeconfig кластера
- `GRAFANA_ADMIN_PASSWORD` - Пароль админа Grafana
