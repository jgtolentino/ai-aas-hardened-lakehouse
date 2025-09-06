#!/bin/bash

# TBWA Neural Workbench v2.0 - Launch Script
# 10-minute magic: CSV → Dashboard → Share

set -e

echo "🧠 TBWA Neural Workbench v2.0"
echo "==============================="
echo "10-minute magic workflow starting..."
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    echo "Please install Python 3.8+ and try again"
    exit 1
fi

# Check if pip is installed
if ! command -v pip &> /dev/null; then
    echo "❌ pip is required but not installed"
    echo "Please install pip and try again"
    exit 1
fi

# Install dependencies if requirements.txt is newer than last install
if [[ ! -f ".last_install" || "requirements.txt" -nt ".last_install" ]]; then
    echo "📦 Installing/updating dependencies..."
    pip install -r requirements.txt
    touch .last_install
    echo "✅ Dependencies installed"
else
    echo "✅ Dependencies up to date"
fi

# Create .env file if it doesn't exist
if [[ ! -f ".env" ]]; then
    echo "⚠️ No .env file found, creating from template..."
    cp .env.example .env
    echo "📝 Please edit .env file with your configuration if needed"
fi

# Check if Streamlit is installed
if ! command -v streamlit &> /dev/null; then
    echo "❌ Streamlit not found in PATH"
    echo "Installing Streamlit..."
    pip install streamlit
fi

echo ""
echo "🚀 Starting TBWA Neural Workbench v2.0..."
echo "📊 Access your app at: http://localhost:8501"
echo ""
echo "Workflow Overview:"
echo "  🔍 Explore: Upload and profile your data"
echo "  🏗️ Build: Create interactive dashboards"  
echo "  🚀 Share: Collaborate and distribute insights"
echo ""
echo "Press Ctrl+C to stop the application"
echo "==============================="

# Launch Streamlit app
streamlit run streamlit_app.py