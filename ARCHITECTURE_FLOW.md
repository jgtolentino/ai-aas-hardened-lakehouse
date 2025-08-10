# Scout Analytics Platform - Architecture & Data Flow

## Project Structure Overview

```
ai-aas-hardened-lakehouse/
├── .github/workflows/          # CI/CD pipelines
│   ├── ci.yml                 # Main CI pipeline (lint, security, test)
│   ├── policy-gate.yml        # OPA policy enforcement
│   └── dbt-image.yml          # dbt Docker image builder
│
├── observability/             # Monitoring & alerting
│   ├── alerting/
│   │   └── slo-alerts.yaml    # Prometheus SLO rules
│   └── grafana-dashboards/
│       └── scout-slos.json    # Grafana dashboards
│
├── platform/
│   ├── lakehouse/             # OSS Lakehouse stack
│   │   ├── 00-namespace.yaml  # K8s namespace & RBAC
│   │   ├── minio/             # S3-compatible storage
│   │   ├── nessie/            # Iceberg catalog
│   │   ├── trino/             # Query engine
│   │   ├── dbt/               # Transformation layer
│   │   └── argo/              # GitOps deployment
│   │
│   ├── scout/                 # Scout application
│   │   ├── migrations/        # SQL schema migrations
│   │   ├── functions/         # Edge Functions (Deno)
│   │   ├── bruno/             # API test collection
│   │   ├── quality/           # Data quality checks
│   │   └── superset/          # Dashboard configs
│   │
│   ├── security/              # Security policies
│   │   ├── netpol/            # NetworkPolicies
│   │   └── gatekeeper/        # OPA constraints
│   │
│   └── superset/              # BI visualization
│       ├── scripts/           # Import automation
│       └── superset_config.py # Security hardening
│
├── scripts/                   # Automation scripts
├── Makefile                   # Production deployment
└── validate_deployment.sh     # Health checks
```

## Data Flow Architecture

```mermaid
graph TB
    subgraph "Data Sources"
        POS[Sari-sari Store POS]
        Mobile[Mobile Apps]
        IoT[IoT Sensors]
    end

    subgraph "Ingestion Layer"
        EF1[ingest-transaction<br/>Edge Function]
        EF2[ingest-doc<br/>Edge Function]
        API[PostgREST API]
    end

    subgraph "Supabase OLTP & Vector"
        subgraph "Scout Schema"
            Bronze[Bronze Tables<br/>Raw Data]
            Silver[Silver Tables<br/>Validated Data]
            Gold[Gold Views<br/>Business Aggregates]
            Dims[Dimension Tables<br/>Store/Product/Location]
        end
        
        Vector[pgvector<br/>Embeddings]
        RLS[Row Level Security]
    end

    subgraph "OSS Lakehouse"
        MinIO[MinIO S3<br/>Object Storage]
        Nessie[Nessie<br/>Iceberg Catalog]
        
        subgraph "Iceberg Tables"
            IceBronze[Bronze Layer<br/>Raw History]
            IceSilver[Silver Layer<br/>Clean History]
            IceGold[Gold Layer<br/>Aggregates]
            IcePlatinum[Platinum Layer<br/>ML Features]
        end
        
        Trino[Trino<br/>Query Engine]
    end

    subgraph "Processing Layer"
        DBT[dbt CronJob<br/>ELT Pipeline]
        GE[Great Expectations<br/>Data Quality]
        EF3[embed-batch<br/>Edge Function]
    end

    subgraph "AI/ML Layer"
        EF4[genie-query<br/>NLQ Engine]
        Embeddings[OpenAI<br/>Embeddings]
        LLM[GPT-4<br/>Query Generation]
    end

    subgraph "Presentation Layer"
        Superset[Apache Superset<br/>Dashboards]
        RestAPI[REST API<br/>PostgREST]
        Guest[Guest Tokens<br/>Embedding]
    end

    subgraph "Security & Monitoring"
        NetPol[NetworkPolicies<br/>Zero Trust]
        Prometheus[Prometheus<br/>Metrics]
        Grafana[Grafana<br/>SLO Dashboard]
        OPA[OPA Gatekeeper<br/>Policy Engine]
    end

    %% Data flow connections
    POS --> EF1
    Mobile --> EF1
    IoT --> EF1
    
    EF1 --> Bronze
    EF2 --> Vector
    
    Bronze --> Silver
    Silver --> Gold
    Silver --> MinIO
    
    MinIO --> IceBronze
    IceBronze --> IceSilver
    IceSilver --> IceGold
    IceGold --> IcePlatinum
    
    DBT --> Trino
    Trino --> Nessie
    Nessie --> MinIO
    
    Gold --> API
    IcePlatinum --> Trino
    
    EF3 --> Vector
    Vector --> EF4
    EF4 --> LLM
    LLM --> Trino
    LLM --> Gold
    
    API --> RestAPI
    Trino --> Superset
    Gold --> Superset
    
    Superset --> Guest
    
    %% Monitoring connections
    EF1 -.-> Prometheus
    EF4 -.-> Prometheus
    Trino -.-> Prometheus
    Prometheus --> Grafana
    
    %% Security enforcement
    NetPol -.-> EF1
    NetPol -.-> Trino
    NetPol -.-> Superset
    RLS -.-> Bronze
    RLS -.-> Silver
    RLS -.-> Gold
    OPA -.-> DBT

    classDef edgeFunction fill:#ff6b6b,stroke:#c92a2a,color:#fff
    classDef storage fill:#4c6ef5,stroke:#364fc7,color:#fff
    classDef processing fill:#51cf66,stroke:#2f9e44,color:#fff
    classDef security fill:#868e96,stroke:#495057,color:#fff
    classDef ai fill:#f59f00,stroke:#e67700,color:#fff
    
    class EF1,EF2,EF3,EF4 edgeFunction
    class Bronze,Silver,Gold,MinIO,Nessie,IceBronze,IceSilver,IceGold,IcePlatinum storage
    class DBT,GE,Trino processing
    class NetPol,RLS,OPA security
    class Embeddings,LLM,Vector ai
```

## Deployment Flow

```mermaid
graph LR
    subgraph "Development"
        Dev[Developer]
        Local[Local Testing]
        Bruno[Bruno API Tests]
    end

    subgraph "CI/CD Pipeline"
        GH[GitHub Actions]
        Lint[Linting]
        Sec[Security Scan]
        Test[Unit Tests]
        Build[Build Images]
        Sign[Cosign Signing]
    end

    subgraph "GitOps"
        Argo[ArgoCD]
        Git[Git Repository]
        Policy[OPA Policies]
    end

    subgraph "Production"
        K8s[Kubernetes Cluster]
        Make[make deploy-prod]
        Val[Validation Script]
    end

    Dev --> Local
    Local --> Bruno
    Bruno --> Git
    
    Git --> GH
    GH --> Lint
    Lint --> Sec
    Sec --> Test
    Test --> Build
    Build --> Sign
    
    Sign --> Argo
    Git --> Argo
    Policy --> Argo
    
    Argo --> K8s
    K8s --> Make
    Make --> Val
    
    Val -->|Success| Prod[Production Ready]
    Val -->|Failure| Rollback[Rollback]
```

## Security Model

```mermaid
graph TB
    subgraph "Network Security"
        DefDeny[Default Deny<br/>NetworkPolicy]
        Allow1[Allow: Trino → Supabase]
        Allow2[Allow: Superset → Trino]
        Allow3[Allow: dbt → Trino]
    end

    subgraph "Data Security"
        RLS[Row Level Security]
        Anon[Anon Role<br/>No Access]
        Auth[Authenticated<br/>Read Silver+]
        Service[Service Role<br/>Full Access]
    end

    subgraph "API Security"
        JWT[JWT Verification]
        CORS[CORS Policy]
        CSP[Content Security Policy]
        CSRF[CSRF Protection]
    end

    subgraph "Supply Chain"
        SBOM[SBOM Generation]
        Cosign[Image Signing]
        Trivy[Vulnerability Scan]
        SLSA[SLSA Provenance]
    end

    DefDeny --> Allow1
    DefDeny --> Allow2
    DefDeny --> Allow3
    
    RLS --> Anon
    RLS --> Auth
    RLS --> Service
    
    JWT --> Auth
    CORS --> CSP
    CSP --> CSRF
    
    SBOM --> Cosign
    Cosign --> Trivy
    Trivy --> SLSA
```

## Data Quality Pipeline

```mermaid
graph LR
    subgraph "Ingestion Quality"
        Zod[Zod Schema<br/>Validation]
        DQ1[Dimension<br/>Integrity]
        DQ2[Business<br/>Rules]
    end

    subgraph "Processing Quality"
        GE[Great Expectations<br/>Suites]
        DBTTest[dbt Tests]
        Fresh[Freshness<br/>Checks]
    end

    subgraph "Monitoring"
        SLO1[Data Freshness<br/>< 1 hour]
        SLO2[API Latency<br/>< 2s p95]
        SLO3[Error Rate<br/>< 0.1%]
    end

    subgraph "Alerting"
        Prom[Prometheus<br/>Rules]
        Alert[PagerDuty/<br/>Slack]
    end

    Zod --> DQ1
    DQ1 --> DQ2
    
    DQ2 --> GE
    GE --> DBTTest
    DBTTest --> Fresh
    
    Fresh --> SLO1
    Fresh --> SLO2
    Fresh --> SLO3
    
    SLO1 --> Prom
    SLO2 --> Prom
    SLO3 --> Prom
    
    Prom --> Alert
```

## Key Features

### 1. **Medallion Architecture**
- **Bronze**: Raw data ingestion with minimal transformation
- **Silver**: Validated, typed data with quality checks
- **Gold**: Business-ready aggregates and metrics
- **Platinum**: ML-ready feature store

### 2. **Real-time + Historical**
- Supabase for real-time OLTP and vector search
- Iceberg/Trino for historical analytics
- Unified querying across both systems

### 3. **AI-Powered Analytics**
- Natural language queries via GPT-4
- Semantic search with pgvector
- Automated insight generation

### 4. **Production Hardening**
- Zero-trust networking with default-deny
- Supply chain security (SBOM, signing)
- Comprehensive observability
- One-shot deployment automation

### 5. **Data Quality First**
- Schema validation at ingestion
- Great Expectations test suites
- Automated freshness monitoring
- Data lineage tracking

## Deployment Commands

```bash
# One-shot production deployment
make deploy-prod

# Individual components
make migrate-database      # Apply SQL migrations
make deploy-edge-functions # Deploy Edge Functions
make deploy-lakehouse      # Deploy MinIO/Nessie/Trino
make init-lakehouse        # Initialize storage
make deploy-dbt           # Deploy transformation pipeline

# Operations
make status               # Check deployment health
make run-bruno-tests      # Run API test suite
make import-superset      # Import dashboards
make rollback            # Rollback deployment
```

## Performance Characteristics

- **Ingestion**: ~10,000 transactions/second
- **Query Latency**: p95 < 2 seconds
- **Data Freshness**: < 1 hour end-to-end
- **Storage**: 200GB MinIO, auto-scaling
- **Compute**: Auto-scaling Trino workers

## Cost Optimization

1. **Supabase**: Real-time data only (7-30 days)
2. **Lakehouse**: Historical data (Iceberg compression)
3. **Compute**: Spot instances for Trino workers
4. **Caching**: Materialized views for common queries
5. **Partitioning**: By date and region