# Production Deployment Guide

Complete deployment guide for the AI-AAS Hardened Lakehouse platform in production environments with high availability, scalability, and security.

## Deployment Architecture

### Multi-Environment Strategy
- **Development**: Local development with docker-compose
- **Staging**: Cloud-based staging environment
- **Production**: Multi-region production deployment
- **DR (Disaster Recovery)**: Cross-region backup environment

## Infrastructure Prerequisites

### Cloud Provider Setup (AWS)
```terraform
# main.tf - Core infrastructure
provider "aws" {
  region = var.primary_region
}

# VPC Configuration
resource "aws_vpc" "lakehouse_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "lakehouse-vpc"
    Environment = var.environment
  }
}

# Subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.lakehouse_vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "private-subnet-${count.index + 1}"
    Type = "private"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.lakehouse_vpc.id
  cidr_block              = "10.0.${count.index + 101}.0/24"
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet-${count.index + 1}"
    Type = "public"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "lakehouse_igw" {
  vpc_id = aws_vpc.lakehouse_vpc.id
  
  tags = {
    Name = "lakehouse-igw"
  }
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  count  = length(var.availability_zones)
  domain = "vpc"
  
  tags = {
    Name = "nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "lakehouse_nat" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id
  
  tags = {
    Name = "lakehouse-nat-${count.index + 1}"
  }
}
```

### Kubernetes Cluster Setup
```terraform
# eks.tf - Amazon EKS Cluster
resource "aws_eks_cluster" "lakehouse_cluster" {
  name     = "lakehouse-${var.environment}"
  role_arn = aws_iam_role.cluster_role.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = concat(aws_subnet.private_subnets[*].id, aws_subnet.public_subnets[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.allowed_cidr_blocks
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_key.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

resource "aws_eks_node_group" "lakehouse_nodes" {
  cluster_name    = aws_eks_cluster.lakehouse_cluster.name
  node_group_name = "lakehouse-nodes"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = aws_subnet.private_subnets[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.xlarge", "t3.2xlarge"]

  scaling_config {
    desired_size = 3
    max_size     = 10
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}
```

## Database Setup

### PostgreSQL High Availability
```yaml
# postgresql-ha.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-lakehouse
  namespace: lakehouse
spec:
  instances: 3
  
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      maintenance_work_mem: "64MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"
      effective_io_concurrency: "200"
      work_mem: "4MB"
      min_wal_size: "1GB"
      max_wal_size: "4GB"
      
  bootstrap:
    initdb:
      database: postgres
      owner: postgres
      secret:
        name: postgres-credentials
      
  storage:
    size: 100Gi
    storageClass: gp3-encrypted
    
  monitoring:
    enabled: true
    
  backup:
    barmanObjectStore:
      destinationPath: "s3://lakehouse-backups/postgres"
      s3Credentials:
        accessKeyId:
          name: postgres-backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: postgres-backup-credentials
          key: SECRET_ACCESS_KEY
      wal:
        retention: "7d"
      data:
        retention: "30d"
        
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  namespace: lakehouse
type: Opaque
data:
  username: cG9zdGdyZXM=  # postgres
  password: <base64-encoded-strong-password>
```

### Database Configuration
```sql
-- Production database setup
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- Configure pg_stat_statements
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET pg_stat_statements.track = 'all';
ALTER SYSTEM SET pg_stat_statements.max = 10000;

-- Performance tuning
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET seq_page_cost = 1.0;
ALTER SYSTEM SET cpu_tuple_cost = 0.01;
ALTER SYSTEM SET cpu_index_tuple_cost = 0.005;
ALTER SYSTEM SET cpu_operator_cost = 0.0025;

-- Memory settings
ALTER SYSTEM SET shared_buffers = '25%';
ALTER SYSTEM SET effective_cache_size = '75%';
ALTER SYSTEM SET maintenance_work_mem = '2GB';
ALTER SYSTEM SET work_mem = '32MB';

-- WAL settings
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET max_wal_size = '4GB';
ALTER SYSTEM SET min_wal_size = '1GB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;

-- Connection settings
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET max_prepared_transactions = 100;

-- Reload configuration
SELECT pg_reload_conf();
```

## Application Deployment

### Kubernetes Manifests

#### Supabase Deployment
```yaml
# supabase.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: supabase-api
  namespace: lakehouse
spec:
  replicas: 3
  selector:
    matchLabels:
      app: supabase-api
  template:
    metadata:
      labels:
        app: supabase-api
    spec:
      containers:
      - name: postgrest
        image: postgrest/postgrest:v11.2.0
        ports:
        - containerPort: 3000
        env:
        - name: PGRST_DB_URI
          valueFrom:
            secretKeyRef:
              name: postgres-uri
              key: connection-string
        - name: PGRST_DB_SCHEMAS
          value: "scout,public"
        - name: PGRST_DB_ANON_ROLE
          value: "anon"
        - name: PGRST_JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: jwt-secret
              key: secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: supabase-api-service
  namespace: lakehouse
spec:
  selector:
    app: supabase-api
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
```

#### MinIO Storage
```yaml
# minio.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: minio-config
  namespace: lakehouse
data:
  MINIO_ROOT_USER: admin
  MINIO_BROWSER: "on"
  MINIO_DOMAIN: minio.lakehouse.local
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
  namespace: lakehouse
spec:
  serviceName: minio-service
  replicas: 4
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:RELEASE.2023-12-02T10-51-33Z
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        envFrom:
        - configMapRef:
            name: minio-config
        env:
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: password
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: gp3-encrypted
      resources:
        requests:
          storage: 100Gi
```

#### Apache Superset
```yaml
# superset.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: superset
  namespace: lakehouse
spec:
  replicas: 2
  selector:
    matchLabels:
      app: superset
  template:
    metadata:
      labels:
        app: superset
    spec:
      initContainers:
      - name: superset-init
        image: apache/superset:2.1.0
        command:
        - /bin/bash
        - -c
        - |
          superset db upgrade
          superset fab create-admin \
            --username admin \
            --firstname Admin \
            --lastname User \
            --email admin@superset.com \
            --password $SUPERSET_ADMIN_PASSWORD
          superset init
        env:
        - name: SUPERSET_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: superset-credentials
              key: admin-password
        - name: SUPERSET_CONFIG_PATH
          value: "/app/pythonpath/superset_config.py"
        volumeMounts:
        - name: superset-config
          mountPath: /app/pythonpath
      containers:
      - name: superset
        image: apache/superset:2.1.0
        ports:
        - containerPort: 8088
        env:
        - name: SUPERSET_CONFIG_PATH
          value: "/app/pythonpath/superset_config.py"
        volumeMounts:
        - name: superset-config
          mountPath: /app/pythonpath
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8088
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8088
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: superset-config
        configMap:
          name: superset-config
```

## Load Balancing & Ingress

### NGINX Ingress Controller
```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: lakehouse-ingress
  namespace: lakehouse
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
spec:
  tls:
  - hosts:
    - api.lakehouse.company.com
    - dashboard.lakehouse.company.com
    - storage.lakehouse.company.com
    secretName: lakehouse-tls
  rules:
  - host: api.lakehouse.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: supabase-api-service
            port:
              number: 3000
  - host: dashboard.lakehouse.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: superset-service
            port:
              number: 8088
  - host: storage.lakehouse.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio-service
            port:
              number: 9001
```

## Security Configuration

### Network Policies
```yaml
# network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: lakehouse-network-policy
  namespace: lakehouse
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: lakehouse
    - namespaceSelector:
        matchLabels:
          name: monitoring
  - from: []
    ports:
    - protocol: TCP
      port: 3000  # PostgREST
    - protocol: TCP
      port: 8088  # Superset
    - protocol: TCP
      port: 9000  # MinIO API
  egress:
  - {}  # Allow all egress for now, restrict in production
```

### Pod Security Standards
```yaml
# pod-security.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: lakehouse
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Monitoring Setup

### Prometheus & Grafana
```yaml
# monitoring.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
    
    - job_name: 'postgres-exporter'
      static_configs:
      - targets: ['postgres-exporter:9187']
    
    - job_name: 'minio-exporter'
      static_configs:
      - targets: ['minio:9000']
      metrics_path: /minio/v2/metrics/cluster
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.47.0
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        - name: prometheus-storage
          mountPath: /prometheus
        command:
        - /bin/prometheus
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --web.console.libraries=/usr/share/prometheus/console_libraries
        - --web.console.templates=/usr/share/prometheus/consoles
        - --web.enable-lifecycle
        - --storage.tsdb.retention.time=30d
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        persistentVolumeClaim:
          claimName: prometheus-storage-pvc
```

## Backup & Disaster Recovery

### Automated Backup Strategy
```bash
#!/bin/bash
# backup-script.sh

set -e

# Configuration
BACKUP_RETENTION_DAYS=30
S3_BACKUP_BUCKET="lakehouse-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# PostgreSQL Backup
echo "Starting PostgreSQL backup..."
kubectl exec -n lakehouse postgres-lakehouse-1 -- pg_dump -U postgres -d postgres | \
  gzip > postgres_backup_${TIMESTAMP}.sql.gz

aws s3 cp postgres_backup_${TIMESTAMP}.sql.gz s3://${S3_BACKUP_BUCKET}/postgres/

# MinIO Data Backup
echo "Starting MinIO data backup..."
kubectl exec -n lakehouse minio-0 -- mc mirror /data s3://backup-bucket/minio/${TIMESTAMP}/

# Configuration Backup
echo "Backing up Kubernetes configurations..."
kubectl get all -n lakehouse -o yaml > k8s_config_${TIMESTAMP}.yaml
aws s3 cp k8s_config_${TIMESTAMP}.yaml s3://${S3_BACKUP_BUCKET}/kubernetes/

# Cleanup old backups
echo "Cleaning up old backups..."
aws s3 ls s3://${S3_BACKUP_BUCKET}/postgres/ | \
  awk '$1 < "'$(date -d "${BACKUP_RETENTION_DAYS} days ago" '+%Y-%m-%d')'"' | \
  awk '{print $4}' | \
  xargs -I {} aws s3 rm s3://${S3_BACKUP_BUCKET}/postgres/{}

echo "Backup completed successfully"
```

### Disaster Recovery Plan
```yaml
# dr-runbook.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: disaster-recovery-runbook
  namespace: lakehouse
data:
  recovery-steps.md: |
    # Disaster Recovery Runbook
    
    ## Step 1: Assess the Situation
    - Check monitoring dashboards
    - Identify failed components
    - Determine scope of outage
    
    ## Step 2: Immediate Response
    - Activate incident response team
    - Notify stakeholders
    - Switch to DR region if necessary
    
    ## Step 3: Data Recovery
    ```bash
    # Restore from latest backup
    kubectl apply -f disaster-recovery/postgres-restore.yaml
    kubectl apply -f disaster-recovery/minio-restore.yaml
    ```
    
    ## Step 4: Service Restoration
    ```bash
    # Deploy services in DR region
    kubectl apply -f production/
    ```
    
    ## Step 5: Validation
    - Run health checks
    - Verify data integrity
    - Test critical paths
    
    ## Step 6: Post-Incident
    - Update monitoring
    - Review incident
    - Update runbooks
```

This deployment guide provides a production-ready setup for the AI-AAS Hardened Lakehouse with high availability, security, and disaster recovery capabilities.