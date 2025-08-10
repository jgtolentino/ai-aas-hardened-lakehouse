#!/bin/bash
# ============================================================================
# Setup Storage Uploader Role
# 
# This script creates the storage_uploader role in your Supabase database
# Run this once to enable secure uploads for edge devices
# ============================================================================

set -euo pipefail

# Check for PGURI
if [ -z "${PGURI:-}" ]; then
    echo "❌ Error: PGURI environment variable not set"
    echo ""
    echo "Please set it to your Supabase connection string:"
    echo "export PGURI='postgresql://postgres:[YOUR-PASSWORD]@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres'"
    echo ""
    echo "You can find this in Supabase Dashboard → Settings → Database"
    exit 1
fi

echo "🔧 Setting up storage_uploader role..."
echo "📍 Database: $(echo $PGURI | sed 's/:[^:]*@/@/g')"  # Hide password in output
echo ""

# Execute the SQL file
if psql "$PGURI" -f scripts/create_storage_uploader_role.sql; then
    echo ""
    echo "✅ Storage uploader role created successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Generate JWT tokens for your colleagues:"
    echo "   node scripts/generate-uploader-token.js"
    echo ""
    echo "2. Give them the generated token (NOT your Service Role Key)"
    echo ""
    echo "3. They can use scripts/edge-upload.sh to upload datasets"
else
    echo ""
    echo "❌ Failed to create storage uploader role"
    echo "Check the error messages above"
    exit 1
fi