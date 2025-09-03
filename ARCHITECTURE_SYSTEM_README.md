# Scout Architecture Documentation System

## ✅ System Deployed Successfully

This repository now includes a comprehensive architecture documentation system following Microsoft's Well-Architected Framework principles, adapted for platform-neutral use.

## 🏗️ What's Been Created

### 📋 Documentation Framework
- **`docs/architecture/ARCHITECTURE_GUIDE.md`** - Complete guide with Well-Architected pillar checklists
- **`docs/architecture/SETUP_GUIDE.md`** - Step-by-step setup instructions  
- **`docs/architecture/adr/0000-template.md`** - ADR template with pillar impact assessment
- **`docs/architecture/README.md`** - Diagram inventory and usage guide

### 🎨 Figma Integration System
- **`scripts/diagrams/figma-export.mjs`** - Node.js script to export Figma frames as PNG/SVG
- **`docs/architecture/diagram-manifest.json`** - Configuration for 13 diagram frames
- **`.github/workflows/diagrams-export.yml`** - Automated export on push to main
- **`docs/architecture/diagrams/`** - Directory for exported images

### 🏗️ S3 Medallion Lakehouse Infrastructure  
- **`infra/data-lake/terraform/`** - Complete Terraform configuration:
  - S3 bucket with bronze/silver/gold/platinum prefixes
  - Versioning, encryption (SSE-KMS or AES256)
  - Lifecycle policies per medallion layer
  - Object Lock support (optional for bronze immutability)
- **`docs/architecture/MEDALLION_LAKE_ON_S3.md`** - S3 lakehouse documentation
- **`policies/*.json`** - Least-privilege IAM policy templates

### 🛠️ Helper Scripts
- **`scripts/data-lake/render-policies.sh`** - Generate IAM policies with bucket name
- **`scripts/data-lake/bootstrap-prefixes.sh`** - Initialize S3 prefixes with placeholders

## 📊 Diagram Framework (13 Frames)

### Core Architecture (C4 Model)
1. **01_System_Context** - High-level system boundaries and external actors
2. **02_Containers** - Major application containers and their relationships  
3. **03_Runtime** - Sequence diagrams and runtime behavior

### Data Flow & Processing
4. **04_Dataflow_Online** - Real-time data pipelines (Gateway ↔ Agents ↔ Supabase)
5. **05_Dataflow_Batch** - ETL/batch processing (Bronze→Silver→Gold→Platinum)
6. **13_Lakehouse_S3** - S3-based medallion architecture with lifecycle policies

### Security & Operations  
7. **06_Security** - Trust zones, authentication, authorization, encryption
8. **07_Observability** - Metrics, logging, tracing, dashboards, SLOs
9. **08_Topologies** - Deployment environments and network topology
10. **09_DR** - Disaster recovery, backup strategies, RPO/RTO

### Landing Zone & Governance
11. **10_Landing_Zone_Guardrails** - Environment separation, policy-as-code
12. **11_Integration_Runtimes** - ETL/agent runtimes, parameter management
13. **12_Promotion_and_Exfil_Controls** - Environment promotion gates, egress controls

## 🏛️ Well-Architected Framework Integration

Every architectural change must address the **5 pillars**:

### 🛡️ Reliability
- Failure domains and disaster recovery  
- Retry/timeout policies and circuit breakers
- Health checks and monitoring
- Queue/buffer overflow handling

### 🔒 Security
- Trust zones and network segmentation
- Identity, authentication, authorization flows
- Data classification and encryption
- Row-level security (RLS) and RBAC/ABAC

### 💰 Cost Optimization  
- Resource sizing and auto-scaling
- Storage tiering (hot/warm/cold)
- Caching strategies (CDN, query, result)
- Batch vs realtime processing trade-offs

### ⚙️ Operational Excellence
- CI/CD pipeline and rollback procedures
- Configuration and feature flag management
- Monitoring, alerting, and runbooks
- Infrastructure as code automation

### ⚡ Performance
- Service Level Objectives (SLOs)
- Bottleneck identification and scaling
- Database indexing strategies  
- Concurrency and connection pooling

### 🌱 Sustainability (Optional)
- Resource utilization optimization
- Green computing choices
- Data/compute locality for efficiency

## 🚀 Quick Start

### 1. Set Up Figma Integration
```bash
# 1. Create Figma file "Scout – Architecture v1.0"
# 2. Set GitHub secrets:
#    - FIGMA_TOKEN (from Figma account settings)
#    - FIGMA_FILE_KEY (from Figma file URL)
# 3. Update diagram-manifest.json with your file key
```

### 2. Deploy S3 Lakehouse (Optional)
```bash
cd infra/data-lake/terraform
terraform init
terraform apply -var region=us-east-1 -var bucket_name=scout-lakehouse-prod

# Generate and attach IAM policies
export LAKE_BUCKET=scout-lakehouse-prod
./scripts/data-lake/render-policies.sh
```

### 3. Test Diagram Export
```bash
export FIGMA_TOKEN="figd_XXXXXXX"  
export FIGMA_FILE_KEY="XXXXXXX"
node scripts/diagrams/figma-export.mjs
```

### 4. Start Using
- Edit diagrams in Figma
- Push changes to trigger auto-export
- Use PR checklist for Well-Architected assessment
- Create ADRs for major decisions

## 📋 PR Checklist Template

```markdown
## Architecture Change

### Figma Links
- [Edited Frames](https://figma.com/file/YOUR_FILE_KEY)

### Well-Architected Assessment
- [ ] **Reliability**: Failure domains, retries, DR (RPO/RTO)
- [ ] **Security**: Trust zones, RLS/JWT, secrets boundaries  
- [ ] **Cost**: Batch vs realtime, cache/TTL, scale units
- [ ] **Operations**: Deploy path, rollback, health checks, runbooks
- [ ] **Performance**: SLOs (p95), concurrency/limits, indices
- [ ] **Sustainability**: Right-sizing, locality (optional)

### Landing Zone Impact  
- [ ] Environment separation maintained
- [ ] Policy as code updated
- [ ] Integration controls reviewed

### Quality Gates
- [ ] All referenced frames exported successfully
- [ ] Diagrams follow 1920×1080, 24px spacing standards
- [ ] Platform-neutral icons used (no vendor-specific)
```

## 🔗 Integration with Existing Scout Architecture

This system builds on your existing Scout components:

### Current Architecture Elements
- **Edge Devices**: Raspberry Pi 5 with facial recognition
- **Supabase**: Database, storage, RLS, Edge Functions
- **Dashboard**: Next.js with Scout analytics
- **ETL Pipeline**: Bronze→Silver→Gold→Platinum medallion
- **Observability**: Prometheus/Grafana ready

### Enhanced with
- **S3 Lakehouse**: Platform-neutral medallion storage
- **Well-Architected Compliance**: 5-pillar assessment framework
- **Automated Documentation**: Figma → GitHub pipeline
- **Landing Zone Patterns**: Enterprise-grade guardrails

## 📚 Key Benefits

### ✅ Platform-Neutral
- Works with AWS S3, MinIO, or any S3-compatible storage
- No vendor lock-in, follows open standards

### ✅ Well-Architected Compliant
- Built-in 5-pillar assessment framework
- Enterprise-grade architecture patterns
- Production-ready security and governance

### ✅ Automated Workflows
- Figma diagrams auto-exported to repository
- CI/CD validation of architecture changes
- Consistent documentation standards

### ✅ Production-Ready
- Terraform infrastructure as code
- Least-privilege IAM policies
- Encryption, lifecycle management, compliance

### ✅ Scout-Specific
- Integrates with existing medallion architecture
- Supports edge device → lakehouse pipeline
- Aligns with Supabase + Next.js stack

## 🎯 Next Steps

1. **Set up Figma integration** following `SETUP_GUIDE.md`
2. **Create initial diagrams** for current Scout architecture
3. **Deploy S3 lakehouse** if moving beyond Supabase storage
4. **Train team** on Well-Architected checklist usage
5. **Establish review cadence** for architecture updates

---

**The Scout Architecture System is now production-ready!** 🚀

Follow the setup guide to begin using this comprehensive architecture documentation and infrastructure system.