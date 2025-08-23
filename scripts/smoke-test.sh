#!/bin/bash
# Smoke tests for AI-AAS Hardened Lakehouse

echo "🔥 Running Smoke Tests..."
echo "========================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test function
test_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$status_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✓${NC} $name (Status: $status_code)"
        echo "  Response: $(echo "$body" | jq -c '.' 2>/dev/null || echo "$body" | head -c 100)"
    else
        echo -e "${RED}✗${NC} $name (Expected: $expected_status, Got: $status_code)"
        echo "  Response: $body"
    fi
    echo
}

# Test API endpoints
echo "1. Testing API Gateway..."
test_endpoint "API Health Check" "http://localhost:8080/health"

echo "2. Testing Geographic Services..."
test_endpoint "Geo Contains" "http://localhost:8080/geo/contains?lat=14.5995&lon=120.9842&level=city"

echo "3. Testing SRP Services..."
test_endpoint "SRP Lookup" "http://localhost:8080/srp?gtin=4800888141019"

echo "4. Testing ML Metrics..."
test_endpoint "ML Daily Metrics" "http://localhost:8080/ml/metrics/daily"
test_endpoint "ML ECE" "http://localhost:8080/ml/ece/brand_detector/v1.0"

echo "5. Testing Transaction Services..."
test_endpoint "Transaction Confidence" "http://localhost:8080/transactions/TX001/confidence"
test_endpoint "Transaction Predictions" "http://localhost:8080/transactions/TX001/predictions"

echo "6. Testing Dashboard Services..."
test_endpoint "Recent Confidences" "http://localhost:8080/transactions/recent-confidences?limit=10"
test_endpoint "SRP Catalog" "http://localhost:8080/srp/catalog?limit=10"
test_endpoint "System Health" "http://localhost:8080/system/health"

echo "7. Testing Brand Detector..."
test_endpoint "Brand Detector Health" "http://localhost:8002/healthz"

# Test dashboard UI
echo "8. Testing Dashboard UI..."
dashboard_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
if [ "$dashboard_response" -eq "200" ]; then
    echo -e "${GREEN}✓${NC} Dashboard UI is accessible"
else
    echo -e "${RED}✗${NC} Dashboard UI not accessible (Status: $dashboard_response)"
fi

echo
echo "========================="
echo "✅ Smoke tests completed!"