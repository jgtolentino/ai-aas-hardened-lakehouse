#!/bin/bash
set -e

echo "🚀 Deploying Scout Analytics to Vercel..."

# Pre-deployment checks
echo "📋 Running pre-deployment checks..."
npm run lint
npm run type-check
npm run test:unit

# Build optimizations
echo "🏗️  Building optimized bundle..."
npm run build

# Deploy to Vercel
echo "☁️  Deploying to Vercel..."
vercel --prod

# Post-deployment validation
echo "🧪 Running post-deployment tests..."
npm run test:e2e:prod

echo "✅ Deployment complete!"
