#\!/usr/bin/env bash
set -euo pipefail
kubectl apply -f platform/lakehouse/00-namespace.yaml
kubectl apply -f platform/security/netpol/00-default-deny.yaml
# Secrets (read README.secrets.md and create first)
kubectl apply -f platform/lakehouse/minio/minio.yaml
kubectl apply -f platform/lakehouse/nessie/nessie.yaml
kubectl apply -f platform/lakehouse/trino/trino.yaml
kubectl apply -f platform/lakehouse/minio/init-bucket.yaml
kubectl apply -f platform/lakehouse/dbt/dbt-cronjob.yaml
echo "[ok] applied core lakehouse resources"
