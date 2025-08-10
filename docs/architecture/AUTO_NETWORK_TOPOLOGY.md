# Scout Platform - Network Architecture
## Auto-Generated from Infrastructure Discovery

```mermaid
graph TB
    subgraph "Internet"
        Users[Users]
        API[API Clients]
    end
    
    subgraph "Edge Layer"
        CF[Cloudflare WAF]
        CDN[CDN Cache]
    end
    
    subgraph "Application Layer"
        subgraph "Supabase"
            EF[Edge Functions]
            PG[(PostgreSQL)]
            ST[Storage]
        end
        
        subgraph "Analytics"
            SS[Superset]
            TR[Trino]
        end
    end
    
    subgraph "Storage Layer"
        MN[MinIO S3]
        IC[Iceberg Tables]
    end
    
    Users --> CF
    API --> CF
    CF --> CDN
    CDN --> EF
    EF --> PG
    PG --> TR
    TR --> IC
    IC --> MN
    SS --> TR
    SS --> PG
```

## Service Endpoints
| Service | Endpoint | Port | Protocol |
|---------|----------|------|----------|
| Supabase API | cxzllzyxwpyptfretryc.supabase.co | 443 | HTTPS |
| PostgreSQL | db.cxzllzyxwpyptfretryc.supabase.co | 5432 | TLS |
| Edge Functions | /functions/v1/* | 443 | HTTPS |
| Superset | superset.scout.analytics | 443 | HTTPS |
