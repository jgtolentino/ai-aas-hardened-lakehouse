#!/bin/bash
# ============================================================================
# Generate Storage Upload Tokens via CLI
# Creates 30-day tokens for colleagues without Node.js
# ============================================================================

set -euo pipefail

# Check for JWT secret
if [ -z "${SUPABASE_JWT_SECRET:-}" ]; then
    echo "❌ Error: SUPABASE_JWT_SECRET not set"
    echo ""
    echo "Get it from Supabase Dashboard → Settings → API → JWT Secret"
    echo "Then run: export SUPABASE_JWT_SECRET='your-secret-here'"
    exit 1
fi

# Configuration
SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"
EXPIRY_DAYS=30

# Function to base64url encode
base64url() {
    # Encode and replace characters for URL safety
    echo -n "$1" | base64 | tr '+/' '-_' | tr -d '='
}

# Function to generate JWT
generate_jwt() {
    local name="$1"
    local token_id=$(openssl rand -hex 8)
    
    # JWT Header
    local header=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64url)
    
    # Current time and expiry (30 days)
    local now=$(date +%s)
    local exp=$((now + (EXPIRY_DAYS * 24 * 60 * 60)))
    
    # JWT Payload
    local payload=$(echo -n "{
        \"role\": \"storage_uploader\",
        \"aud\": \"authenticated\",
        \"token_id\": \"$token_id\",
        \"token_name\": \"$name\",
        \"permissions\": [\"storage.upload\", \"storage.read\"],
        \"allowed_buckets\": [\"sample\"],
        \"allowed_paths\": [\"scout/v1/**\"],
        \"iat\": $now,
        \"exp\": $exp
    }" | tr -d '\n' | tr -s ' ' | base64url)
    
    # Create signature
    local data="${header}.${payload}"
    local signature=$(echo -n "$data" | openssl dgst -sha256 -hmac "$SUPABASE_JWT_SECRET" -binary | base64url)
    
    # Complete JWT
    local jwt="${data}.${signature}"
    
    # Create output file
    local output_file="token-${name}-${token_id}.txt"
    
    cat > "$output_file" << EOF
# ============================================
# Storage Upload Token for: $name
# ============================================

Token ID: $token_id
Created: $(date)
Expires: $(date -d "@$exp" 2>/dev/null || date -r "$exp")
Duration: $EXPIRY_DAYS days

## 1. Save this .env file:
------- START .env -------
SUPABASE_URL=$SUPABASE_URL
SUPABASE_STORAGE_TOKEN=$jwt
------- END .env -------

## 2. Test upload command:
curl -X POST "$SUPABASE_URL/storage/v1/object/sample/scout/v1/test.txt" \\
  -H "Authorization: Bearer \$SUPABASE_STORAGE_TOKEN" \\
  -H "Content-Type: text/plain" \\
  -d "Test upload from $name"

## 3. Use edge-upload.sh script:
./edge-upload.sh /path/to/datasets

## Security Notes:
- Can ONLY upload to scout/v1/* paths
- Cannot delete files or access database
- Expires automatically in $EXPIRY_DAYS days
EOF

    echo "✅ Token generated: $output_file"
    echo "   Token ID: $token_id"
    echo ""
}

# Main execution
echo "🔐 Generating 30-day Storage Upload Tokens"
echo "=========================================="
echo ""

# Generate tokens for both colleagues
generate_jwt "colleague1-pi5"
generate_jwt "colleague2-pi5"

echo "📋 Summary:"
echo "- Both tokens expire in 30 days"
echo "- Tokens saved to token-*.txt files"
echo "- Share these files with your colleagues"
echo ""
echo "⚠️  Security Reminder:"
echo "- Never share the SUPABASE_JWT_SECRET"
echo "- These tokens can ONLY upload to scout/v1/*"
echo "- Tokens cannot delete files or access the database"