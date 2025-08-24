# Migration Files Comparison Report

## Repository Structure Overview

### scout-databank-new
- `/supabase/migrations/` - Contains 10 migration files
- `/ai-aas-hardened-lakehouse/supabase/migrations/` - Contains 5 migration files (subset)
- `/ai-aas-hardened-lakehouse/db/migrations/` - Contains 59 migration files

### ai-aas-hardened-lakehouse
- `/supabase/migrations/` - Contains 7 migration files
- `/db/migrations/` - Contains 59 migration files
- `/platform/scout/blueprint-dashboard/supabase/migrations/` - Contains 9 migration files
- `/platform/scout/scout-databank/supabase/migrations/` - Contains 3 migration files

## Key Findings

### 1. Missing Migrations in ai-aas-hardened-lakehouse

#### From scout-databank-new/supabase/migrations:
The following migrations exist in scout-databank-new but are missing from ai-aas-hardened-lakehouse main supabase/migrations:
- `20250120_scout_health_extensions_SAFE.sql`
- `20250120_scout_rag_knowledge_base.sql`
- `20250823_ai_reasoning_tracking.sql`
- `20250823_fix_missing_tables.sql`
- `20250823_nl_to_sql_feature.sql`
- `20250823_sari_sari_expert.sql`

Note: Some of these (`20250823_rls_gold_only.sql`, `20250823_scout_agentic_core.sql`, `20250823_scout_exec_rpc.sql`) exist in a different location: `/platform/scout/scout-databank/supabase/migrations/`

#### From ai-aas-hardened-lakehouse/db/migrations:
The following migrations exist only in ai-aas-hardened-lakehouse and not in scout-databank-new:
- `026_brand_detection_schema.sql`
- `110_geo_boundaries.sql`
- `111_srp_catalog.sql`
- `112_resolvers.sql`
- `120_ml_monitoring.sql`
- `121_tx_confidence.sql`

### 2. Duplicated Migrations

Both repositories contain these migrations but in different directories:
- `20250810_qa_results.sql` - exists in multiple locations
- Various dataset-related migrations (022-025)
- Multiple zz_* prefixed migrations in db/migrations

### 3. Migration Numbering Conflicts

The repositories use different numbering schemes:
- scout-databank-new: Uses date-based naming (YYYYMMDD_description.sql)
- ai-aas-hardened-lakehouse: Mixed approach with:
  - Sequential numbers (000-121)
  - Date-based (20250119_, 20250120_, etc.)
  - zz_ prefix for many migrations

### 4. Location Misalignment

The same migrations are stored in different directories:
- Scout agent-related migrations are split between:
  - scout-databank-new: `/supabase/migrations/`
  - ai-aas-hardened-lakehouse: `/platform/scout/scout-databank/supabase/migrations/`

### 5. Missing Critical Migrations

Important migrations that should be synchronized:
1. **Scout Health Extensions** (`20250120_scout_health_extensions_SAFE.sql`) - Missing in ai-aas-hardened-lakehouse
2. **Scout RAG Knowledge Base** (`20250120_scout_rag_knowledge_base.sql`) - Missing in ai-aas-hardened-lakehouse
3. **AI Reasoning Tracking** (`20250823_ai_reasoning_tracking.sql`) - Missing in ai-aas-hardened-lakehouse
4. **NL to SQL Feature** (`20250823_nl_to_sql_feature.sql`) - Missing in ai-aas-hardened-lakehouse

## Recommendations

1. **Consolidate Migration Locations**: Choose a single directory structure for migrations
2. **Synchronize Missing Migrations**: Copy missing critical migrations to ai-aas-hardened-lakehouse
3. **Standardize Naming Convention**: Use consistent date-based naming (YYYYMMDD_description.sql)
4. **Remove Duplicates**: Eliminate duplicate migrations across different directories
5. **Create Migration Index**: Document which migrations have been applied to which environments

## Action Items

1. Copy these files from scout-databank-new to ai-aas-hardened-lakehouse/supabase/migrations:
   - `20250120_scout_health_extensions_SAFE.sql`
   - `20250120_scout_rag_knowledge_base.sql`
   - `20250823_ai_reasoning_tracking.sql`
   - `20250823_fix_missing_tables.sql`
   - `20250823_nl_to_sql_feature.sql`
   - `20250823_sari_sari_expert.sql`

2. Review and potentially migrate unique ai-aas-hardened-lakehouse migrations to scout-databank-new:
   - `026_brand_detection_schema.sql`
   - `110_geo_boundaries.sql`
   - `111_srp_catalog.sql`
   - `112_resolvers.sql`
   - `120_ml_monitoring.sql`
   - `121_tx_confidence.sql`

3. Consolidate the scattered scout-databank migrations from `/platform/scout/scout-databank/supabase/migrations/`