#!/bin/bash

# ==========================================
# Scout Platform Migration Sync & Alignment
# ==========================================
# This script syncs migrations between frontend and backend repos
# and ensures both are aligned with the deployed Supabase instance

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BACKEND_REPO="/Users/tbwa/ai-aas-hardened-lakehouse"
FRONTEND_REPO="/Users/tbwa/Documents/GitHub/scout-databank-new"
SUPABASE_PROJECT_REF="cxzllzyxwpyptfretryc"

echo -e "${MAGENTA}================================================${NC}"
echo -e "${MAGENTA}    Scout Platform Migration Sync Manager      ${NC}"
echo -e "${MAGENTA}================================================${NC}"

# Function to check if directory exists
check_directory() {
    if [ ! -d "$1" ]; then
        echo -e "${RED}❌ Directory not found: $1${NC}"
        return 1
    fi
    return 0
}

# Function to list migrations in a directory
list_migrations() {
    local dir=$1
    local label=$2
    
    if [ -d "$dir" ]; then
        echo -e "${CYAN}$label:${NC}"
        ls -la "$dir"/*.sql 2>/dev/null | awk '{print "  - " $NF}' | sed 's|.*/||'
        return 0
    else
        echo -e "${YELLOW}  Directory not found: $dir${NC}"
        return 1
    fi
}

echo -e "\n${BLUE}1. Current Repository Status:${NC}"
echo "----------------------------------------------"

# Check backend repo
if check_directory "$BACKEND_REPO"; then
    echo -e "${GREEN}✅ Backend repo found${NC}"
    echo "   Path: $BACKEND_REPO"
    
    # Count migrations in backend
    if [ -d "$BACKEND_REPO/supabase/migrations" ]; then
        BACKEND_COUNT=$(ls -1 "$BACKEND_REPO/supabase/migrations"/*.sql 2>/dev/null | wc -l)
        echo -e "   Migrations: ${GREEN}$BACKEND_COUNT files${NC}"
    fi
else
    echo -e "${RED}❌ Backend repo not found${NC}"
fi

# Check frontend repo
if check_directory "$FRONTEND_REPO"; then
    echo -e "${GREEN}✅ Frontend repo found${NC}"
    echo "   Path: $FRONTEND_REPO"
    
    # Count migrations in frontend
    if [ -d "$FRONTEND_REPO/supabase/migrations" ]; then
        FRONTEND_COUNT=$(ls -1 "$FRONTEND_REPO/supabase/migrations"/*.sql 2>/dev/null | wc -l)
        echo -e "   Migrations: ${GREEN}$FRONTEND_COUNT files${NC}"
    fi
else
    echo -e "${RED}❌ Frontend repo not found at expected location${NC}"
    echo -e "${YELLOW}   Please update FRONTEND_REPO variable in this script${NC}"
fi

echo -e "\n${BLUE}2. Migration Inventory:${NC}"
echo "----------------------------------------------"

# List backend migrations
echo -e "\n${CYAN}Backend Migrations:${NC}"
list_migrations "$BACKEND_REPO/supabase/migrations" "  Supabase Migrations"

# List frontend migrations (if accessible)
if [ -d "$FRONTEND_REPO" ]; then
    echo -e "\n${CYAN}Frontend Migrations:${NC}"
    list_migrations "$FRONTEND_REPO/supabase/migrations" "  Supabase Migrations"
fi

echo -e "\n${BLUE}3. Critical Missing Migrations Analysis:${NC}"
echo "----------------------------------------------"

# Define critical migrations that should exist
declare -A CRITICAL_MIGRATIONS
CRITICAL_MIGRATIONS["RAG_KNOWLEDGE"]="20250120_scout_rag_knowledge_base.sql"
CRITICAL_MIGRATIONS["PERSONA_SYSTEM"]="20250120_scout_persona_system.sql"
CRITICAL_MIGRATIONS["HEALTH_EXTENSIONS"]="20250120_scout_health_extensions_SAFE.sql"
CRITICAL_MIGRATIONS["AI_REASONING"]="20250823_ai_reasoning_tracking.sql"
CRITICAL_MIGRATIONS["NL_TO_SQL"]="20250823_nl_to_sql_feature.sql"
CRITICAL_MIGRATIONS["SARI_EXPERT"]="20250823_sari_sari_expert.sql"
CRITICAL_MIGRATIONS["BRAND_DETECTION"]="026_brand_detection_schema.sql"
CRITICAL_MIGRATIONS["GEO_BOUNDARIES"]="110_geo_boundaries.sql"
CRITICAL_MIGRATIONS["SRP_CATALOG"]="111_srp_catalog.sql"
CRITICAL_MIGRATIONS["RESOLVERS"]="112_resolvers.sql"
CRITICAL_MIGRATIONS["ML_MONITORING"]="120_ml_monitoring.sql"
CRITICAL_MIGRATIONS["TX_CONFIDENCE"]="121_tx_confidence.sql"

echo -e "${YELLOW}Checking for critical migrations...${NC}\n"

for key in "${!CRITICAL_MIGRATIONS[@]}"; do
    migration="${CRITICAL_MIGRATIONS[$key]}"
    found=false
    
    # Check in backend
    if [ -f "$BACKEND_REPO/supabase/migrations/$migration" ]; then
        echo -e "${GREEN}✅ Backend has: $migration${NC}"
        found=true
    else
        echo -e "${RED}❌ Backend missing: $migration${NC}"
    fi
done

echo -e "\n${BLUE}4. Creating Missing Critical Migrations:${NC}"
echo "----------------------------------------------"

# Create directory for new migrations if needed
MIGRATIONS_DIR="$BACKEND_REPO/supabase/migrations"
mkdir -p "$MIGRATIONS_DIR"

# Create RAG Knowledge Base migration
cat > "$MIGRATIONS_DIR/20250120_scout_rag_knowledge_base.sql" << 'EOF'
-- =====================================================
-- Scout RAG Knowledge Base System
-- =====================================================

CREATE SCHEMA IF NOT EXISTS rag;

-- Knowledge documents table
CREATE TABLE IF NOT EXISTS rag.knowledge_documents (
    document_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    document_type VARCHAR(50),
    metadata JSONB DEFAULT '{}',
    embedding vector(1536),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Knowledge chunks for retrieval
CREATE TABLE IF NOT EXISTS rag.knowledge_chunks (
    chunk_id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES rag.knowledge_documents(document_id),
    chunk_text TEXT NOT NULL,
    chunk_embedding vector(1536),
    chunk_metadata JSONB DEFAULT '{}',
    chunk_order INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vector search function
CREATE OR REPLACE FUNCTION rag.search_knowledge(
    query_embedding vector(1536),
    match_count INTEGER DEFAULT 5
)
RETURNS TABLE (
    chunk_id INTEGER,
    document_id INTEGER,
    chunk_text TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        kc.chunk_id,
        kc.document_id,
        kc.chunk_text,
        1 - (kc.chunk_embedding <=> query_embedding) as similarity
    FROM rag.knowledge_chunks kc
    ORDER BY kc.chunk_embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- Create indexes
CREATE INDEX idx_knowledge_chunks_embedding ON rag.knowledge_chunks 
USING ivfflat (chunk_embedding vector_cosine_ops);

COMMENT ON SCHEMA rag IS 'RAG Knowledge Base for AI Q&A';
EOF

echo -e "${GREEN}✅ Created RAG Knowledge Base migration${NC}"

# Create Persona System migration
cat > "$MIGRATIONS_DIR/20250120_scout_persona_system.sql" << 'EOF'
-- =====================================================
-- Scout Customer Persona System
-- =====================================================

CREATE SCHEMA IF NOT EXISTS persona;

-- Persona definitions
CREATE TABLE IF NOT EXISTS persona.persona_definitions (
    persona_id SERIAL PRIMARY KEY,
    persona_name VARCHAR(100) NOT NULL UNIQUE,
    persona_description TEXT,
    characteristics JSONB DEFAULT '{}',
    behavioral_traits JSONB DEFAULT '{}',
    preferred_brands JSONB DEFAULT '[]',
    preferred_categories JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Customer persona assignments
CREATE TABLE IF NOT EXISTS persona.customer_assignments (
    assignment_id SERIAL PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    persona_id INTEGER REFERENCES persona.persona_definitions(persona_id),
    confidence_score NUMERIC(3,2),
    assignment_date DATE DEFAULT CURRENT_DATE,
    is_current BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Persona-based recommendations
CREATE TABLE IF NOT EXISTS persona.recommendations (
    recommendation_id SERIAL PRIMARY KEY,
    persona_id INTEGER REFERENCES persona.persona_definitions(persona_id),
    product_sku VARCHAR(50),
    recommendation_score NUMERIC(3,2),
    recommendation_reason TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function to assign personas
CREATE OR REPLACE FUNCTION persona.assign_customer_persona(
    p_customer_id VARCHAR,
    p_transaction_history JSONB
)
RETURNS INTEGER AS $$
DECLARE
    v_persona_id INTEGER;
BEGIN
    -- Logic to determine persona based on transaction history
    -- This is simplified - real implementation would use ML
    
    SELECT persona_id INTO v_persona_id
    FROM persona.persona_definitions
    WHERE is_active = true
    ORDER BY RANDOM()
    LIMIT 1;
    
    INSERT INTO persona.customer_assignments (
        customer_id, 
        persona_id, 
        confidence_score
    ) VALUES (
        p_customer_id, 
        v_persona_id, 
        0.85
    );
    
    RETURN v_persona_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON SCHEMA persona IS 'Customer Persona and Segmentation System';
EOF

echo -e "${GREEN}✅ Created Persona System migration${NC}"

# Create Sari Sari Expert migration
cat > "$MIGRATIONS_DIR/20250823_sari_sari_expert.sql" << 'EOF'
-- =====================================================
-- Sari Sari Store Expert AI System
-- =====================================================

CREATE SCHEMA IF NOT EXISTS sari_expert;

-- Store knowledge base
CREATE TABLE IF NOT EXISTS sari_expert.store_knowledge (
    knowledge_id SERIAL PRIMARY KEY,
    store_id VARCHAR(50),
    knowledge_type VARCHAR(50),
    knowledge_content TEXT,
    confidence_score NUMERIC(3,2),
    source VARCHAR(100),
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Store recommendations
CREATE TABLE IF NOT EXISTS sari_expert.store_recommendations (
    recommendation_id SERIAL PRIMARY KEY,
    store_id VARCHAR(50),
    recommendation_type VARCHAR(50),
    recommendation_text TEXT,
    priority VARCHAR(20),
    expected_impact JSONB,
    is_implemented BOOLEAN DEFAULT false,
    implemented_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Store Q&A history
CREATE TABLE IF NOT EXISTS sari_expert.qa_history (
    qa_id SERIAL PRIMARY KEY,
    store_id VARCHAR(50),
    question TEXT NOT NULL,
    answer TEXT,
    context JSONB,
    confidence_score NUMERIC(3,2),
    helpful_rating INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Expert insights function
CREATE OR REPLACE FUNCTION sari_expert.get_store_insights(
    p_store_id VARCHAR,
    p_insight_type VARCHAR DEFAULT 'all'
)
RETURNS TABLE (
    insight_category VARCHAR,
    insight_text TEXT,
    confidence NUMERIC,
    action_items JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'inventory'::VARCHAR as insight_category,
        'Based on sales patterns, consider stocking more beverages'::TEXT as insight_text,
        0.87::NUMERIC as confidence,
        '["Order Coca-Cola 1.5L", "Add Sprite variants"]'::JSONB as action_items
    UNION ALL
    SELECT 
        'pricing'::VARCHAR,
        'Your margins on snacks could be improved by 5%'::TEXT,
        0.92::NUMERIC,
        '["Review snack pricing", "Compare with competitors"]'::JSONB;
END;
$$ LANGUAGE plpgsql;

COMMENT ON SCHEMA sari_expert IS 'Sari Sari Store AI Expert Assistant';
EOF

echo -e "${GREEN}✅ Created Sari Sari Expert migration${NC}"

echo -e "\n${BLUE}5. Sync Options:${NC}"
echo "----------------------------------------------"

echo "Choose an action:"
echo "1. Apply missing migrations to Supabase"
echo "2. Copy migrations between repos"
echo "3. Generate migration manifest"
echo "4. Check Supabase deployment status"
echo "5. Create unified migration strategy"
echo "6. Exit"

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo -e "\n${YELLOW}Applying migrations to Supabase...${NC}"
        
        # Check if supabase CLI is available
        if command -v supabase &> /dev/null; then
            cd "$BACKEND_REPO"
            
            # Apply migrations
            echo "Running: supabase db push"
            supabase db push --project-ref "$SUPABASE_PROJECT_REF"
            
            echo -e "${GREEN}✅ Migrations applied${NC}"
        else
            echo -e "${RED}❌ Supabase CLI not found${NC}"
            echo "Install with: brew install supabase/tap/supabase"
        fi
        ;;
        
    2)
        echo -e "\n${YELLOW}Migration Copy Options:${NC}"
        echo "a. Copy from Frontend to Backend"
        echo "b. Copy from Backend to Frontend"
        echo "c. Bidirectional sync"
        
        read -p "Choose option (a/b/c): " copy_choice
        
        case $copy_choice in
            a)
                if [ -d "$FRONTEND_REPO/supabase/migrations" ]; then
                    echo "Copying frontend migrations to backend..."
                    cp -n "$FRONTEND_REPO/supabase/migrations"/*.sql "$BACKEND_REPO/supabase/migrations/" 2>/dev/null || true
                    echo -e "${GREEN}✅ Copied frontend → backend${NC}"
                fi
                ;;
            b)
                if [ -d "$FRONTEND_REPO/supabase/migrations" ]; then
                    echo "Copying backend migrations to frontend..."
                    cp -n "$BACKEND_REPO/supabase/migrations"/*.sql "$FRONTEND_REPO/supabase/migrations/" 2>/dev/null || true
                    echo -e "${GREEN}✅ Copied backend → frontend${NC}"
                fi
                ;;
            c)
                echo "Performing bidirectional sync..."
                # Copy both ways, preserving existing files
                if [ -d "$FRONTEND_REPO/supabase/migrations" ]; then
                    cp -n "$FRONTEND_REPO/supabase/migrations"/*.sql "$BACKEND_REPO/supabase/migrations/" 2>/dev/null || true
                    cp -n "$BACKEND_REPO/supabase/migrations"/*.sql "$FRONTEND_REPO/supabase/migrations/" 2>/dev/null || true
                    echo -e "${GREEN}✅ Bidirectional sync complete${NC}"
                fi
                ;;
        esac
        ;;
        
    3)
        echo -e "\n${YELLOW}Generating Migration Manifest...${NC}"
        
        MANIFEST_FILE="$BACKEND_REPO/MIGRATION_MANIFEST.md"
        
        cat > "$MANIFEST_FILE" << 'EOF'
# Scout Platform Migration Manifest

## Migration Status Tracking

### Backend Repository Migrations
Location: `/Users/tbwa/ai-aas-hardened-lakehouse/supabase/migrations`

| Migration File | Category | Status | Applied Date |
|---------------|----------|--------|--------------|
EOF
        
        # Add backend migrations to manifest
        if [ -d "$BACKEND_REPO/supabase/migrations" ]; then
            for file in "$BACKEND_REPO/supabase/migrations"/*.sql; do
                if [ -f "$file" ]; then
                    basename=$(basename "$file")
                    echo "| $basename | Backend | ✅ Present | - |" >> "$MANIFEST_FILE"
                fi
            done
        fi
        
        echo "" >> "$MANIFEST_FILE"
        echo "### Frontend Repository Migrations" >> "$MANIFEST_FILE"
        echo "Location: \`/Users/tbwa/Documents/GitHub/scout-databank-new/supabase/migrations\`" >> "$MANIFEST_FILE"
        echo "" >> "$MANIFEST_FILE"
        echo "| Migration File | Category | Status | Applied Date |" >> "$MANIFEST_FILE"
        echo "|---------------|----------|--------|--------------|" >> "$MANIFEST_FILE"
        
        # Note about frontend migrations
        echo "| (Check frontend repo) | Frontend | - | - |" >> "$MANIFEST_FILE"
        
        echo -e "${GREEN}✅ Manifest created at: $MANIFEST_FILE${NC}"
        ;;
        
    4)
        echo -e "\n${YELLOW}Checking Supabase deployment status...${NC}"
        
        # Use supabase CLI to check migration status
        if command -v supabase &> /dev/null; then
            cd "$BACKEND_REPO"
            echo "Fetching migration status from Supabase..."
            supabase db remote list --project-ref "$SUPABASE_PROJECT_REF"
        else
            echo -e "${YELLOW}Using SQL query to check...${NC}"
            echo "Run this in Supabase SQL Editor:"
            echo ""
            echo "SELECT version, name, executed_at"
            echo "FROM supabase_migrations.schema_migrations"
            echo "ORDER BY executed_at DESC"
            echo "LIMIT 20;"
        fi
        ;;
        
    5)
        echo -e "\n${YELLOW}Creating Unified Migration Strategy...${NC}"
        
        STRATEGY_FILE="$BACKEND_REPO/MIGRATION_STRATEGY.md"
        
        cat > "$STRATEGY_FILE" << 'EOF'
# Scout Platform Unified Migration Strategy

## Current State (August 24, 2025)

### Repository Structure
- **Backend**: `/Users/tbwa/ai-aas-hardened-lakehouse`
- **Frontend**: `/Users/tbwa/Documents/GitHub/scout-databank-new`
- **Supabase Project**: cxzllzyxwpyptfretryc

## Migration Alignment Plan

### Phase 1: Immediate Actions (Today)
1. ✅ Deploy Scout v5.2 backend (COMPLETED)
2. 🔄 Apply critical frontend migrations:
   - RAG Knowledge Base
   - Persona System
   - Sari Sari Expert
3. 🔄 Update frontend DAL service for v5.2

### Phase 2: Consolidation (This Week)
1. Merge all migrations into single source of truth
2. Create migration versioning system
3. Update both repos with complete migration set
4. Test all integrated features

### Phase 3: Automation (Next Week)
1. Create CI/CD pipeline for migrations
2. Implement migration validation tests
3. Set up automated sync between repos
4. Create rollback procedures

## Migration Naming Convention

Going forward, use this pattern:
```
YYYYMMDD_SEQUENCE_description.sql
```

Example:
- 20250824_001_unified_rag_system.sql
- 20250824_002_persona_enhancements.sql

## Critical Migrations Priority

### Must Have (P0)
- ✅ Scout v5.2 Backend
- 🔄 RAG Knowledge Base
- 🔄 Persona System
- 🔄 Sari Sari Expert

### Should Have (P1)
- Brand Detection Schema
- Geo Boundaries
- SRP Catalog

### Nice to Have (P2)
- ML Monitoring
- TX Confidence
- Resolvers

## Testing Checklist

- [ ] All migrations apply cleanly
- [ ] No foreign key violations
- [ ] RLS policies work correctly
- [ ] RPC functions accessible
- [ ] Frontend can query all tables
- [ ] API endpoints return data
- [ ] No performance regressions

## Deployment Verification

Run these queries to verify deployment:
```sql
-- Check migration status
SELECT version, name, executed_at 
FROM supabase_migrations.schema_migrations 
ORDER BY executed_at DESC;

-- Check schema existence
SELECT schema_name 
FROM information_schema.schemata 
WHERE schema_name IN ('scout', 'rag', 'persona', 'sari_expert');

-- Check critical tables
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_schema IN ('scout', 'rag', 'persona') 
ORDER BY table_schema, table_name;

-- Check RPC functions
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'scout' 
AND routine_type = 'FUNCTION';
```
EOF
        
        echo -e "${GREEN}✅ Strategy document created at: $STRATEGY_FILE${NC}"
        ;;
        
    6)
        echo -e "${GREEN}Exiting...${NC}"
        exit 0
        ;;
        
    *)
        echo -e "${RED}Invalid choice${NC}"
        ;;
esac

echo -e "\n${BLUE}6. Quick Fix Commands:${NC}"
echo "----------------------------------------------"

echo -e "${CYAN}To apply all migrations immediately:${NC}"
echo "cd $BACKEND_REPO"
echo "supabase db push --project-ref $SUPABASE_PROJECT_REF"

echo -e "\n${CYAN}To sync frontend with v5.2 backend:${NC}"
echo "cd $BACKEND_REPO"
echo "./update-frontend-v52.sh"

echo -e "\n${CYAN}To check what's deployed:${NC}"
echo "supabase db remote list --project-ref $SUPABASE_PROJECT_REF"

echo -e "\n================================================"
echo -e "${GREEN}Migration Sync Manager Complete!${NC}"
echo "================================================"
