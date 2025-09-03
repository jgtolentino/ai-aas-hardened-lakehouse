# Scout Architecture – Diagram & Docs Standard

## Purpose
Consistent, platform-neutral diagrams + checklists aligned to Well-Architected pillars:
Reliability, Security, Cost, Operational Excellence, Performance (Sustainability optional).

## Figma conventions
- File: **Scout – Architecture v1.0**
- Pages: 00 Legend & Tokens, 01 System Context, 02 Product Architecture / Containers,
  03 Runtime / Sequences, 04 Dataflow – Online, 05 Dataflow – Batch,
  06 Security & IAM, 07 Observability & SLOs, 08 Deploy Topologies, 09 DR / Backup / Recovery,
  10 Landing Zone Guardrails, 11 Integration Runtimes, 12 Promotion and Exfil Controls,
  13 Lakehouse S3, 14 Change Log
- Frames (export ids): 01_System_Context, 02_Containers, 03_Runtime, 04_Dataflow_Online,
  05_Dataflow_Batch, 06_Security, 07_Observability, 08_Topologies, 09_DR,
  10_Landing_Zone_Guardrails, 11_Integration_Runtimes, 12_Promotion_and_Exfil_Controls, 13_Lakehouse_S3
- Size: 1920×1080, 12-col grid, 24px spacing.
- Icons: brand kit + neutral set (no vendor-specific). Maintain a legend in page 00.

## File outputs
Export PNG (docs render) + SVG (source) into `docs/architecture/diagrams/`.

## PR checklist (required)
- [ ] Figma link to frames edited
- [ ] Exported images updated via exporter
- [ ] Pillar impacts documented:
  - **Reliability**: failure domains, retries, DR (RPO/RTO)
  - **Security**: trust zones, RLS/JWT, secrets boundaries
  - **Cost**: batch vs realtime, cache/TTL, scale units
  - **Ops**: deploy path, rollback, health checks, runbooks
  - **Performance**: SLOs (p95), concurrency/limits, indices
  - **Sustainability (opt)**: right-sizing / locality
- [ ] Data lineage shown for Bronze→Silver→Gold→Platinum
- [ ] Observability: metrics/logs/traces, dashboards/alerts
- [ ] External dependencies and SLAs annotated
- [ ] Landing zone guardrails: environment separation, policy-as-code, secrets management
- [ ] Integration runtime controls: parameter sets, egress allow-lists, promotion gates

## Scout-specific diagram anchors
- Agents & Gateway, MM-Scorer, Dashboard (Next.js), Supabase (DB+Storage+RLS),
  Edge Functions, ETL/Lakehouse, Observability (Prometheus/Grafana), CI/CD, Secrets/KMS.

## Well-Architected Pillar Requirements

### Reliability
- **Failure Domains**: Show compute, storage, network failure boundaries
- **Retry/Timeout**: Document retry policies, circuit breakers, backpressure
- **DR**: RPO/RTO targets, backup strategies, failover procedures
- **Health Checks**: Application and infrastructure health monitoring
- **Queue/Buffer**: Show async processing and queue overflow handling

### Security  
- **Trust Zones**: Network segmentation, security boundaries
- **Identity**: Authentication flows, service accounts, key management
- **Data Classification**: PII, sensitive data handling and encryption
- **RLS/Authorization**: Row-level security, RBAC, ABAC implementations
- **Secrets**: Secure parameter passing, secret rotation

### Cost Optimization
- **Resource Sizing**: Right-sizing decisions, auto-scaling triggers
- **Storage Tiering**: Hot/warm/cold data lifecycle policies
- **Caching**: CDN, query cache, result cache strategies
- **Batch vs Realtime**: Processing mode trade-offs
- **Reserved vs On-Demand**: Capacity planning decisions

### Operational Excellence
- **Deploy Pipeline**: CI/CD flow, rollback procedures, canary deployment
- **Configuration**: Environment-specific config, feature flags
- **Monitoring**: Metrics, logs, traces, dashboards, alerting
- **Runbooks**: Incident response, maintenance procedures
- **Automation**: Infrastructure as code, automated remediation

### Performance
- **SLOs**: Service level objectives (latency, throughput, availability)
- **Bottlenecks**: Identified performance constraints
- **Scaling**: Horizontal and vertical scaling strategies
- **Indexing**: Database and search indexing strategies
- **Concurrency**: Connection pooling, rate limiting, load balancing

### Sustainability (Optional)
- **Right-sizing**: Resource optimization for minimal environmental impact
- **Locality**: Data and compute placement for efficiency
- **Utilization**: High resource utilization targets
- **Renewable Energy**: Green compute choices where applicable

## Landing Zone Guardrails (Enterprise)

### Environment Separation
- **Dev/Stage/Prod**: Clear environment boundaries and promotion flow
- **Network Isolation**: VPC/subnet isolation, firewall rules
- **Data Isolation**: Separate databases, storage accounts per environment
- **Access Control**: Environment-specific IAM roles and policies

### Policy as Code
- **Infrastructure**: Terraform, CloudFormation, ARM templates
- **Security**: Policy definitions, compliance scanning
- **Cost Management**: Budget policies, resource tagging
- **Governance**: Naming conventions, resource lifecycle

### Identity and Access Management
- **Service Principals**: Dedicated service accounts per component
- **Least Privilege**: Minimal required permissions
- **MFA**: Multi-factor authentication requirements
- **Key Management**: Centralized secret and key rotation

### Integration Runtime Controls
- **Parameter Sets**: Environment-specific configuration management
- **Egress Control**: Outbound connectivity restrictions and allow-lists
- **Promotion Gates**: Quality gates between environments
- **Audit Trail**: Complete change and access logging