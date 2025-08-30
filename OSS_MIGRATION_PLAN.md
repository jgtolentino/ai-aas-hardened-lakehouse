# 🔄 Scout Agentic Architecture Alignment
## Preserving Working Features, Replacing Licensed Components

### ✅ **What We KEEP (Already Working)**

```yaml
Working_Components:
  Frontend:
    - scout-dashboard (React/Tailwind)
    - ChartVision overlays
    - SUQI AI templates
    - WrenAI semantic search
    
  Backend:
    - Supabase (Postgres + Storage + Edge Functions)
    - Bronze → Silver → Gold pipeline
    - RLS policies + Views
    - Anomaly detection functions
    
  Agentic_Layer:
    - Claude Desktop MCP Hub
    - MCP adapters (Figma, GitHub, Supabase)
    - Reasoning chains
    - Agent queue system
    
  Data_Pipeline:
    - S3/ADLS2 ingestion
    - scout.* schema
    - Predictive metrics
    - Campaign detection
```

### ❌ **What We DEPRECATE (License Required)**

```yaml
Remove_From_Specs:
  Azure:
    - Azure AI Foundry ❌
    - Azure AI Studio ❌
    - Azure Prompt Flow ❌
    - Azure ML Registry ❌
    
  Databricks:
    - Unity Catalog ❌
    - Delta Lake (licensed version) ❌
    - Databricks Workflows ❌
    - MLflow (Databricks-hosted) ❌
```

### 🔄 **OSS Replacements (No License Required)**

```yaml
Open_Source_Equivalents:
  Model_Serving:
    deprecated: "Azure AI Endpoints"
    replacement: "vLLM or Ollama (self-hosted)"
    location: "infra/ai-foundry/vllm/"
    
  Model_Registry:
    deprecated: "Azure ML Registry"
    replacement: "MLflow OSS (self-hosted)"
    location: "infra/ai-foundry/mlflow/"
    
  Workflow_Orchestration:
    deprecated: "Azure Prompt Flow"
    replacement: "LangChain/LangGraph"
    location: "packages/langchain-flows/"
    
  Data_Catalog:
    deprecated: "Unity Catalog"
    replacement: "Apache Iceberg on Supabase"
    location: "supabase/migrations/iceberg_tables.sql"
    
  Vector_Store:
    deprecated: "Azure Cognitive Search"
    replacement: "pgvector (already in Supabase)"
    location: "existing - no change"
```

---

## 📁 **Repository Structure (No Breaking Changes)**

```bash
ai-aas-hardened-lakehouse/
├── apps/scout-dashboard/           # ✅ NO CHANGE - Working
├── packages/
│   ├── contracts/                  # ✅ NO CHANGE - Working
│   └── langchain-flows/            # 🆕 ADD - Replaces Azure Prompt Flow
│       ├── src/
│       │   ├── chains/
│       │   │   ├── anomaly-detection.ts
│       │   │   ├── campaign-inference.ts
│       │   │   └── competitive-intel.ts
│       │   └── index.ts
│       └── package.json
├── supabase/                       # ✅ NO CHANGE - Working
│   ├── migrations/
│   ├── functions/
│   └── seed.sql
├── infra/
│   ├── mcp-hub/                    # ✅ NO CHANGE - Working
│   └── ai-foundry/                 # 🆕 ADD - OSS Stack
│       ├── docker-compose.yml      # vLLM + MLflow + MinIO
│       ├── vllm/
│       │   └── config.yaml
│       ├── mlflow/
│       │   └── config.yaml
│       └── README.md
└── docs/
    ├── DEPRECATED_AZURE.md         # 🆕 Document what's removed
    └── OSS_EQUIVALENTS.md          # 🆕 Migration guide
```

---

## 🎯 **Agentic RAG Flow (Using Existing Components)**

```mermaid
graph LR
    A[User Query] --> B[Claude Desktop MCP]
    B --> C{Route Decision}
    
    C -->|Data Query| D[Supabase MCP]
    C -->|Design Query| E[Figma MCP]
    C -->|Code Query| F[GitHub MCP]
    
    D --> G[pgvector + RLS]
    E --> H[Design Tokens]
    F --> I[Code Context]
    
    G --> J[Retrieved Context]
    H --> J
    I --> J
    
    J --> K[Claude Reasoning]
    K --> L{Validation}
    
    L -->|Valid| M[Response + Action]
    L -->|Invalid| B
    
    M --> N[Automated Execution]
    N --> O[Edge Functions]
```

**This flow uses ONLY existing working components!**

---

## 🔧 **Implementation Plan (Preserve Working Features)**

### Phase 1: Document Deprecations
```bash
# Create deprecation notices
echo "# Deprecated Components" > docs/DEPRECATED_AZURE.md
echo "- Azure AI Foundry → vLLM" >> docs/DEPRECATED_AZURE.md
echo "- Unity Catalog → Iceberg" >> docs/DEPRECATED_AZURE.md
echo "- Azure Prompt Flow → LangChain" >> docs/DEPRECATED_AZURE.md
```

### Phase 2: Add OSS Equivalents (Non-Breaking)
```yaml
# infra/ai-foundry/docker-compose.yml
version: '3.8'
services:
  vllm:
    image: vllm/vllm-openai:latest
    volumes:
      - ./models:/models
    environment:
      - MODEL_NAME=meta-llama/Llama-3.2-3B-Instruct
    ports:
      - "8000:8000"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
  
  mlflow:
    image: ghcr.io/mlflow/mlflow:latest
    ports:
      - "5000:5000"
    environment:
      - BACKEND_STORE_URI=postgresql://postgres:password@supabase-db:5432/mlflow
      - DEFAULT_ARTIFACT_ROOT=s3://mlflow/
    depends_on:
      - minio
  
  minio:
    image: minio/minio:latest
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      - MINIO_ROOT_USER=minioadmin
      - MINIO_ROOT_PASSWORD=minioadmin
    command: server /data --console-address ":9001"
```

### Phase 3: Update Specs/Backlogs
```typescript
// packages/langchain-flows/src/chains/anomaly-detection.ts
import { ChatOpenAI } from "@langchain/openai";
import { PromptTemplate } from "@langchain/core/prompts";
import { createClient } from '@supabase/supabase-js';

// This REPLACES Azure Prompt Flow, uses existing Supabase data
export async function detectAnomalies() {
  const supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );
  
  // Query existing anomaly view
  const { data: anomalies } = await supabase
    .from('scout.sku_regional_anomalies')
    .select('*')
    .gt('lift_percentage', 150);
  
  // Use local vLLM instead of Azure
  const llm = new ChatOpenAI({
    openAIApiKey: "EMPTY",
    configuration: {
      baseURL: "http://localhost:8000/v1"
    }
  });
  
  // Same logic, different infrastructure
  const chain = PromptTemplate.fromTemplate(
    "Analyze these anomalies and recommend actions: {anomalies}"
  ).pipe(llm);
  
  return await chain.invoke({ anomalies });
}
```

---

## ✅ **What This Achieves**

1. **NO breaking changes** to working features
2. **NO modifications** to scout-dashboard, Supabase schema, or MCP Hub
3. **ONLY deprecates** license-requiring components
4. **ADDS OSS alternatives** in parallel (non-invasive)
5. **PRESERVES** all agentic capabilities

### Working Features Preserved:
- ✅ Anomaly detection
- ✅ Campaign inference  
- ✅ Competitive intelligence
- ✅ Predictive metrics
- ✅ Agent reasoning chains
- ✅ MCP orchestration

### License Requirements Removed:
- ❌ Azure AI Foundry → ✅ vLLM
- ❌ Unity Catalog → ✅ Iceberg
- ❌ Azure Prompt Flow → ✅ LangChain
- ❌ Databricks MLflow → ✅ MLflow OSS

---

## 📝 **Migration Path (Non-Destructive)**

```bash
# Step 1: Keep everything working
git checkout -b add-oss-equivalents

# Step 2: Add OSS components alongside
mkdir -p infra/ai-foundry
mkdir -p packages/langchain-flows

# Step 3: Test OSS components
cd infra/ai-foundry
docker-compose up -d

# Step 4: Update docs only
echo "Azure components deprecated in favor of OSS" >> docs/CHANGELOG.md

# Step 5: Specs point to OSS
# Update planning.md to reference vLLM instead of Azure
# Update tasks.md to use LangChain instead of Prompt Flow

# Step 6: Merge when ready
git merge add-oss-equivalents
```

---

## 🎯 **Summary**

**We're NOT changing what works.**
**We're ONLY replacing what requires licenses.**

The agentic architecture remains intact:
- Claude Desktop MCP → Still the brain
- Supabase → Still the data layer
- Edge Functions → Still the execution layer
- MCP Hub → Still the orchestration layer

We just swap out:
- Azure AI → vLLM (local)
- Unity Catalog → Iceberg (on Supabase)
- Prompt Flow → LangChain (in packages/)

**Result**: Same agentic capabilities, zero license fees! 🚀
