# Hardened OSS Lakehouse (Supabase + MinIO + Nessie + Trino) — up to PLATINUM

**What's included**
- MinIO (PVC, probes, limits) + bucket init job
- Nessie catalog
- Trino (Iceberg + Supabase Postgres catalogs), no public ingress by default
- Default-deny NetworkPolicy + per-service allows
- dbt project (Bronze→Silver→Gold→Platinum) targeting Trino/Iceberg
- dbt runner image (GHCR) + Kubernetes CronJob to run nightly
- ArgoCD application to sync `platform/lakehouse/**`

## Before you apply
1. Create secrets per `platform/lakehouse/configs/README.secrets.md`.
2. (Optional) Push dbt image by merging to main (GH Actions builds to GHCR).
3. (Optional) Enable Ingress for Trino by renaming `ingress.disabled.yaml` and setting TLS + allowlist.

## Apply
```bash
kubectl apply -f platform/lakehouse/00-namespace.yaml
kubectl apply -f platform/security/netpol/00-default-deny.yaml
# create secrets per README.secrets.md
kubectl apply -f platform/lakehouse/minio/minio.yaml
kubectl apply -f platform/lakehouse/nessie/nessie.yaml
kubectl apply -f platform/lakehouse/trino/trino.yaml
kubectl apply -f platform/lakehouse/minio/init-bucket.yaml
# dbt CronJob (pulls GHCR image)
kubectl apply -f platform/lakehouse/dbt/dbt-cronjob.yaml
```

## Create Iceberg schemas (gold/silver/bronze/platinum)

Port-forward Trino:

```bash
kubectl -n aaas port-forward svc/trino 8080:8080 &
```

Then:

```bash
curl -s http://localhost:8080/v1/statement -H 'X-Trino-User: admin' -H 'Content-Type: text/plain' \
  --data-binary "CREATE SCHEMA IF NOT EXISTS iceberg.bronze WITH (location='s3a://lakehouse/bronze')"
curl -s http://localhost:8080/v1/statement -H 'X-Trino-User: admin' -H 'Content-Type: text/plain' \
  --data-binary "CREATE SCHEMA IF NOT EXISTS iceberg.silver WITH (location='s3a://lakehouse/silver')"
curl -s http://localhost:8080/v1/statement -H 'X-Trino-User: admin' -H 'Content-Type: text/plain' \
  --data-binary "CREATE SCHEMA IF NOT EXISTS iceberg.gold WITH (location='s3a://lakehouse/gold')"
curl -s http://localhost:8080/v1/statement -H 'X-Trino-User: admin' -H 'Content-Type: text/plain' \
  --data-binary "CREATE SCHEMA IF NOT EXISTS iceberg.platinum WITH (location='s3a://lakehouse/platinum')"
```

## Map Supabase table for BRONZE

Ensure Trino's Postgres catalog can see your Supabase table as `public.analytics_sales`.
If your table is `analytics.sales`, create a Supabase view:

```sql
create or replace view public.analytics_sales as
select * from analytics.sales;
```

## Run dbt in-cluster

* GH Action builds `ghcr.io/<OWNER>/ai-aas-hardened-lakehouse-dbt:latest`
* CronJob runs nightly using that image

## Security notes

* Default deny NetworkPolicy is on.
* Trino has no public ingress; enable only with TLS and IP allowlist.
* MinIO uses PVC; replace `emptyDir` nowhere (done).
* Add Gatekeeper policies if you want global enforcement (templates stubbed in security/gatekeeper).

