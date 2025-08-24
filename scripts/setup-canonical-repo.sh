#!/bin/bash
# ============================================================
# SETUP CANONICAL PRODUCTION DB REPOSITORY
# One-time setup for ai-aas-hardened-lakehouse as the source of truth
# ============================================================

set -e

PROJECT_REF="cxzllzyxwpyptfretryc"
REPO_NAME="ai-aas-hardened-lakehouse"

echo "🚀 CANONICAL DB REPO SETUP"
echo "============================"
echo "Repository: $REPO_NAME"
echo "Project: $PROJECT_REF"
echo ""

# Check if we're in the right directory
if [[ ! $(basename "$PWD") == "$REPO_NAME" ]]; then
    echo "❌ Please run this script from the $REPO_NAME directory"
    echo "   Current directory: $(basename "$PWD")"
    exit 1
fi

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install with: npm i -g supabase@latest"
    exit 1
fi

echo "1️⃣ INITIALIZING SUPABASE PROJECT"
echo "=================================="

# Initialize Supabase project (if not already done)
if [ ! -f "supabase/config.toml" ]; then
    echo "   📦 Initializing new Supabase project..."
    supabase init --quiet
else
    echo "   ✅ Supabase project already initialized"
fi

# Update config.toml with correct project reference
echo "   🔧 Updating project reference..."
if grep -q "project_ref" supabase/config.toml; then
    # Replace existing project_ref
    sed -i.bak "s/project_ref = .*/project_ref = \"$PROJECT_REF\"/" supabase/config.toml
else
    # Add project_ref after project_id
    awk '/project_id/&&c++==0{print; print "project_ref = \"'$PROJECT_REF'\""; next}1' supabase/config.toml > /tmp/config && mv /tmp/config supabase/config.toml
fi

echo "   ✅ Project reference updated to $PROJECT_REF"

echo ""
echo "2️⃣ CREATING DIRECTORY STRUCTURE"
echo "================================="

# Ensure required directories exist
directories=(
    "supabase/migrations"
    "supabase/functions"
    "supabase/storage"
    "data"
    "scripts"
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "   📁 Created $dir/"
    else
        echo "   ✅ Directory exists: $dir/"
    fi
done

echo ""
echo "3️⃣ LINKING TO PRODUCTION PROJECT"
echo "=================================="

echo "   🔗 Linking to production project..."
if supabase link --project-ref "$PROJECT_REF" --no-open 2>/dev/null; then
    echo "   ✅ Successfully linked to production"
else
    echo "   ⚠️  Link failed - you may need to run 'supabase login' first"
    echo "      Run: supabase login"
    echo "      Then: supabase link --project-ref $PROJECT_REF"
fi

echo ""
echo "4️⃣ VALIDATING GITHUB SECRETS"
echo "============================="

echo "   📋 Required GitHub Secrets (add these in repo Settings > Secrets):"
echo "      SUPABASE_ACCESS_TOKEN  = sbp_... (from https://app.supabase.com/account/tokens)"
echo "      SUPABASE_PROJECT_REF   = $PROJECT_REF"
echo "      SUPABASE_DB_URL        = postgresql://... (from Supabase dashboard)"
echo ""

# Test connection if linked successfully
if supabase projects list &>/dev/null; then
    echo "   🔍 Testing connection..."
    if echo "SELECT 'Connection test OK' as status;" | supabase db execute &>/dev/null; then
        echo "   ✅ Database connection successful"
        
        # Get some basic info about the production database
        echo ""
        echo "   📊 Production Database Status:"
        echo "SELECT 
          current_database() as database,
          current_user as user,
          version() as postgres_version
        ;" | supabase db execute || true
        
    else
        echo "   ❌ Database connection failed"
    fi
else
    echo "   ⚠️  Cannot test connection - not linked yet"
fi

echo ""
echo "5️⃣ MIGRATION STATUS CHECK"
echo "=========================="

# Check current migration status
echo "   📝 Checking migration status..."
if ls supabase/migrations/*.sql &>/dev/null; then
    echo "   ✅ Migration files found:"
    ls -1 supabase/migrations/*.sql | wc -l | xargs echo "      Count:"
    
    # Show first few migrations
    echo "      Recent migrations:"
    ls -t supabase/migrations/*.sql | head -5 | xargs -I {} basename {} | sed 's/^/        /'
else
    echo "   ⚠️  No migration files found in supabase/migrations/"
fi

echo ""
echo "6️⃣ WORKFLOW VALIDATION"
echo "======================"

workflows=(
    ".github/workflows/ci.yml"
    ".github/workflows/deploy-prod.yml"
)

for workflow in "${workflows[@]}"; do
    if [ -f "$workflow" ]; then
        echo "   ✅ Workflow exists: $workflow"
    else
        echo "   ❌ Missing workflow: $workflow"
    fi
done

echo ""
echo "🎯 NEXT STEPS"
echo "=============="
echo "1. Add GitHub Secrets (see section 4 above)"
echo "2. Upload seed data: ./scripts/upload-seeds.sh"
echo "3. Test deployment: git push origin main"
echo "4. Monitor workflows: https://github.com/[your-username]/$REPO_NAME/actions"
echo ""

echo "📋 USEFUL COMMANDS"
echo "==================="
echo "• Check drift:        supabase db diff"
echo "• Apply migrations:   supabase db push"
echo "• Load seed data:     SELECT scout.fn_load_seed_data();"
echo "• Reset local DB:     supabase db reset"
echo "• View logs:          supabase functions logs"
echo ""

echo "🔗 PRODUCTION URLS"
echo "=================="
echo "• Supabase Dashboard: https://app.supabase.com/project/$PROJECT_REF"
echo "• Database URL:       https://app.supabase.com/project/$PROJECT_REF/settings/database"
echo "• Storage:            https://app.supabase.com/project/$PROJECT_REF/storage/buckets"
echo "• API Documentation:  https://app.supabase.com/project/$PROJECT_REF/api/docs"
echo ""

# Final status
if [ -f "supabase/config.toml" ] && [ -f ".github/workflows/ci.yml" ] && [ -f ".github/workflows/deploy-prod.yml" ]; then
    echo "✅ SETUP COMPLETED SUCCESSFULLY!"
    echo "   $REPO_NAME is now the canonical production DB repository"
else
    echo "⚠️  SETUP INCOMPLETE - some files may be missing"
fi

echo ""
echo "🚀 Ready to deploy Scout v5.2 with automated CI/CD!"