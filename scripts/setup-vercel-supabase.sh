#!/usr/bin/env bash
set -euo pipefail

# Vercel Supabase Environment Setup Script
# Run this to set up all Supabase environment variables in Vercel

PROJECT_REF="sbp_830d652c8d86db9dd9a7e907f1c6ab3a8b0bb781"
SUPABASE_URL="https://${PROJECT_REF}.supabase.co"

echo "Setting up Supabase environment variables for Vercel..."
echo "Project Reference: $PROJECT_REF"
echo

# Read values from .env file
if [ -f .env ]; then
  ANON_KEY=$(grep "^NEXT_PUBLIC_SUPABASE_ANON_KEY=" .env | cut -d '=' -f2-)
  SERVICE_ROLE_KEY=$(grep "^SUPABASE_SERVICE_ROLE_KEY=" .env | cut -d '=' -f2-)
  DB_URL=$(grep "^SUPABASE_DB_URL=" .env | cut -d '=' -f2-)
  
  echo "Found environment variables from .env file"
else
  echo "Error: .env file not found. Please make sure you have the correct Supabase credentials."
  exit 1
fi

# Vercel environment variable commands
echo "Run these commands to set up Vercel environment variables:"
echo
echo "# Frontend variables (browser-safe)"
echo "vercel env add NEXT_PUBLIC_SUPABASE_URL $SUPABASE_URL"
echo "vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY $ANON_KEY"
echo
echo "# Server-only variables"
echo "vercel env add SUPABASE_URL $SUPABASE_URL"
echo "vercel env add SUPABASE_SERVICE_ROLE_KEY $SERVICE_ROLE_KEY"
echo "vercel env add SUPABASE_PROJECT_REF $PROJECT_REF"
echo "vercel env add SUPABASE_DB_URL $DB_URL"
echo
echo "# Optional: For GitHub Actions sync workflows"
echo "vercel env add SUPABASE_ACCESS_TOKEN $PROJECT_REF --git-branch main"
echo
echo "Make sure to run these commands in the correct Vercel project directory!"
echo "You can also set these in the Vercel dashboard under Settings → Environment Variables"
