Create these secrets in the aaas namespace:

1) Supabase source (for Trino postgres catalog)
kubectl -n aaas create secret generic supabase-source \
  --from-literal=PG_HOST=db.YOUR_REF.supabase.co \
  --from-literal=PG_PORT=5432 \
  --from-literal=PG_DB=postgres \
  --from-literal=PG_USER=postgres \
  --from-literal=PG_PASS=REPLACE \
  -o yaml --dry-run=client | kubectl apply -f -

2) MinIO keys
kubectl -n aaas create secret generic minio-keys \
  --from-literal=access_key=minioadmin \
  --from-literal=secret_key=minioadmin \
  -o yaml --dry-run=client | kubectl apply -f -

3) Trino aggregated env (reads both supabase+minio+nessie endpoints)
kubectl -n aaas create secret generic trino-secrets \
  --from-literal=MINIO_ENDPOINT=http://minio.aaas.svc.cluster.local:9000 \
  --from-literal=MINIO_ACCESS=minioadmin \
  --from-literal=MINIO_SECRET=minioadmin \
  --from-literal=NESSIE_URI=http://nessie.aaas.svc.cluster.local:19120/api/v2 \
  --from-literal=PG_HOST=db.YOUR_REF.supabase.co \
  --from-literal=PG_PORT=5432 \
  --from-literal=PG_DB=postgres \
  --from-literal=PG_USER=postgres \
  --from-literal=PG_PASS=REPLACE \
  -o yaml --dry-run=client | kubectl apply -f -
