#!/usr/bin/env bash
# Vercel Supabase One-Liner Setup
# Run this to automatically set all Supabase environment variables in Vercel

set -euo pipefail

PROJECT_REF="cxzllzyxwpyptfretryc"
SUPABASE_URL="https://${PROJECT_REF}.supabase.co"

echo "🚀 Setting up Supabase environment variables in Vercel..."
echo "📋 Project Reference: $PROJECT_REF"
echo

if [ -f .env ]; then
  ANON_KEY=$(grep "^NEXT_PUBLIC_SUPABASE_ANON_KEY=" .env | cut -d '=' -f2-)
  SERVICE_ROLE_KEY=$(grep "^SUPABASE_SERVICE_ROLE_KEY=" .env | cut -d '=' -f2-)
  DB_URL=$(grep "^SUPABASE_DB_URL=" .env | cut -d '=' -f2-)
  
  echo "✅ Found environment variables from .env file"
else
  echo "❌ Error: .env file not found"
  exit 1
fi

echo
echo "📝 Copy and run this one-liner to set up all Vercel environment variables:"
echo
echo "vercel env add NEXT_PUBLIC_SUPABASE_URL $SUPABASE_URL && \\"
echo "vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY $ANON_KEY && \\"
echo "vercel env add SUPABASE_URL $SUPABASE_URL && \\"
echo "vercel env add SUPABASE_SERVICE_ROLE_KEY $SERVICE_ROLE_KEY && \\"
echo "vercel env add SUPABASE_PROJECT_REF $PROJECT_REF && \\"
echo "vercel env add SUPABASE_DB_URL '$DB_URL'"
echo
echo "💡 Tip: Make sure you're in the correct Vercel project directory!"
echo "📊 You can also set these manually in Vercel dashboard → Settings → Environment Variables"
