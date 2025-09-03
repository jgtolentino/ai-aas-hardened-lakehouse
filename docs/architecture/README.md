# Scout Architecture

Diagrams exported from Figma live in `./diagrams/`.  
Update by running:

```bash
FIGMA_TOKEN=*** FIGMA_FILE_KEY=*** node scripts/diagrams/figma-export.mjs
```

See **ARCHITECTURE_GUIDE.md** for conventions and the PR checklist.

## Diagram Inventory

### Core Architecture (C4 Model)
- **01_System_Context**: High-level system boundaries and external actors
- **02_Containers**: Major application containers and their relationships
- **03_Runtime**: Sequence diagrams and runtime behavior

### Data Flow & Processing
- **04_Dataflow_Online**: Real-time data pipelines (Gateway ↔ Agents ↔ Supabase)
- **05_Dataflow_Batch**: ETL/batch processing (Bronze→Silver→Gold→Platinum)
- **13_Lakehouse_S3**: S3-based medallion architecture with lifecycle policies

### Security & Operations
- **06_Security**: Trust zones, authentication, authorization, encryption
- **07_Observability**: Metrics, logging, tracing, dashboards, SLOs
- **08_Topologies**: Deployment environments and network topology
- **09_DR**: Disaster recovery, backup strategies, RPO/RTO

### Landing Zone & Governance
- **10_Landing_Zone_Guardrails**: Environment separation, policy-as-code
- **11_Integration_Runtimes**: ETL/agent runtimes, parameter management
- **12_Promotion_and_Exfil_Controls**: Environment promotion gates, egress controls

## Usage in Documentation

Reference diagrams in docs using:

```markdown
![System Context](./diagrams/01_System_Context.png)

*Figure 1: Scout system context showing external integrations*
```

## Figma File Structure

The Figma file follows a standardized structure:
- **Page 00**: Legend, color tokens, icon library
- **Pages 01-13**: Individual diagram frames (see inventory above)
- **Page 14**: Change log and version history

All diagrams use:
- 1920×1080 frame size
- 12-column grid system  
- 24px base spacing
- Consistent color palette
- Platform-neutral icons