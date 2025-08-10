#!/bin/bash
# Scout Documentation - Quick Setup Script

set -e

echo "🚀 Scout Documentation Quick Setup"
echo "=================================="

# Check prerequisites
check_prerequisite() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        exit 1
    fi
    echo "✅ $1 found"
}

echo ""
echo "Checking prerequisites..."
check_prerequisite node
check_prerequisite npm
check_prerequisite git

# Setup documentation site
echo ""
echo "📚 Setting up Docusaurus documentation site..."
cd docs-site

# Install dependencies
echo "Installing dependencies..."
npm install

# Generate initial documentation
echo ""
echo "📊 Generating documentation..."
cd ..
chmod +x scripts/generate_docs.sh
# Note: This would normally run but requires database connection
# ./scripts/generate_docs.sh

# Create some sample generated docs for demo
mkdir -p docs/data/lineage
mkdir -p docs/operations/runbooks
mkdir -p docs/ml/model-cards
mkdir -p docs/finops
mkdir -p docs/api

echo "Creating sample documentation..."

# Sample lineage doc
cat > docs/data/lineage/sample_lineage.md << 'EOF'
# Data Lineage
Auto-generated documentation sample.
View full lineage after connecting to database.
EOF

# Sample cost doc
cat > docs/finops/sample_cost.md << 'EOF'
# Cost Report
Monthly cost: $2,400 (70% below market rate)
EOF

# Return to docs-site
cd docs-site

echo ""
echo "✅ Documentation site ready!"
echo ""
echo "Available commands:"
echo "  npm start          - Start development server (http://localhost:3001)"
echo "  npm run build      - Build production site"
echo "  npm run serve      - Serve production build"
echo "  npm run generate   - Regenerate documentation (requires DB connection)"
echo ""
echo "To start the documentation site:"
echo "  cd docs-site && npm start"
echo ""
echo "📖 Happy documenting!"
