#!/bin/bash
# Deploy Superset with Mapbox integration and proper secret handling

set -euo pipefail

# Configuration
NAMESPACE="${NAMESPACE:-aaas}"
RELEASE_NAME="${RELEASE_NAME:-superset}"
MAPBOX_TOKEN="${MAPBOX_API_KEY:-}"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Deploying Superset with Mapbox Integration"
echo "============================================"

# Check if Mapbox token is provided
if [ -z "$MAPBOX_TOKEN" ]; then
    echo -e "${RED}❌ MAPBOX_API_KEY environment variable not set${NC}"
    echo "Please set: export MAPBOX_API_KEY='pk.your_actual_token_here'"
    exit 1
fi

# Validate Mapbox token format
if [[ ! "$MAPBOX_TOKEN" =~ ^pk\. ]]; then
    echo -e "${RED}❌ Invalid Mapbox token format (should start with 'pk.')${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Creating namespace if needed...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n${YELLOW}2. Creating Mapbox secret...${NC}"
kubectl -n "$NAMESPACE" create secret generic superset-mapbox \
  --from-literal=MAPBOX_API_KEY="$MAPBOX_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Secret created/updated${NC}"

echo -e "\n${YELLOW}3. Adding Helm repository...${NC}"
helm repo add apache https://apache.github.io/superset || true
helm repo update

echo -e "\n${YELLOW}4. Deploying Superset with overlay...${NC}"
if [ ! -f "helm-overlays/superset-values-prod.yaml" ]; then
    echo -e "${RED}❌ Values file not found: helm-overlays/superset-values-prod.yaml${NC}"
    exit 1
fi

# Deploy or upgrade
helm upgrade --install "$RELEASE_NAME" apache/superset \
  -n "$NAMESPACE" \
  -f helm-overlays/superset-values-prod.yaml \
  --wait \
  --timeout 10m

echo -e "\n${YELLOW}5. Waiting for rollout...${NC}"
kubectl -n "$NAMESPACE" rollout status deployment/"$RELEASE_NAME"

echo -e "\n${YELLOW}6. Verifying configuration...${NC}"
# Check if env vars are properly set
POD_NAME=$(kubectl -n "$NAMESPACE" get pods -l "app.kubernetes.io/name=superset,app.kubernetes.io/instance=$RELEASE_NAME" -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}❌ No Superset pod found${NC}"
    exit 1
fi

echo "Checking environment variables in pod: $POD_NAME"
kubectl -n "$NAMESPACE" exec "$POD_NAME" -- sh -c '
echo "MAPBOX_API_KEY is set: $([ -n "$MAPBOX_API_KEY" ] && echo "Yes" || echo "No")"
echo "SUPERSET_CONFIG_PATH: $SUPERSET_CONFIG_PATH"
echo "Python check:"
python -c "
import os
mapbox_key = os.getenv(\"MAPBOX_API_KEY\", \"\")
print(f\"  Mapbox key length: {len(mapbox_key)}\")
print(f\"  Mapbox key starts with pk.: {mapbox_key.startswith(\"pk.\")}\")
print(f\"  Config path exists: {os.path.exists(os.getenv(\"SUPERSET_CONFIG_PATH\", \"\"))}\")
"
'

echo -e "\n${YELLOW}7. Testing Superset API access...${NC}"
# Get service info
SERVICE_NAME=$(kubectl -n "$NAMESPACE" get svc -l "app.kubernetes.io/name=superset,app.kubernetes.io/instance=$RELEASE_NAME" -o jsonpath="{.items[0].metadata.name}")
SERVICE_PORT=$(kubectl -n "$NAMESPACE" get svc "$SERVICE_NAME" -o jsonpath="{.spec.ports[0].port}")

echo "Service: $SERVICE_NAME:$SERVICE_PORT"

# Port forward for testing
echo -e "\n${YELLOW}8. Setting up port forward for testing...${NC}"
kubectl -n "$NAMESPACE" port-forward "svc/$SERVICE_NAME" 8088:"$SERVICE_PORT" &
PF_PID=$!
sleep 5

# Test API
echo -e "\n${YELLOW}9. Testing Superset API...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8088/api/v1/security/login || echo "000")

if [ "$HTTP_CODE" = "405" ] || [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✅ Superset API responding (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}❌ Superset API not responding properly (HTTP $HTTP_CODE)${NC}"
fi

# Kill port forward
kill $PF_PID 2>/dev/null || true

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Superset Deployment Complete${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\nNext steps:"
echo "1. Access Superset: kubectl -n $NAMESPACE port-forward svc/$SERVICE_NAME 8088:$SERVICE_PORT"
echo "2. Import assets: bash platform/superset/scripts/import_scout_bundle.sh"
echo "3. Test choropleth maps in the UI"
echo ""
echo "To check logs: kubectl -n $NAMESPACE logs -l app.kubernetes.io/name=superset"