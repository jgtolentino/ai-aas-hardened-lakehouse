#!/bin/bash

# PowerBI/Tableau Bridge Management Script
# Extends dual-bridge architecture for enterprise BI dashboard integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MCP_HUB_DIR="$PROJECT_ROOT/infra/mcp-hub"
BRIDGE_PORT=${BRIDGE_PORT:-3002}
PID_FILE="/tmp/bi-bridge.pid"
LOG_FILE="/tmp/bi-bridge.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[BI Bridge]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[BI Bridge]${NC} $1"
}

error() {
    echo -e "${RED}[BI Bridge]${NC} $1"
    exit 1
}

# Check if bridge is running
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Start the bridge
start_bridge() {
    if is_running; then
        warn "BI Bridge already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    log "Starting PowerBI/Tableau Bridge..."
    
    # Check if MCP Hub exists
    if [[ ! -d "$MCP_HUB_DIR" ]]; then
        error "MCP Hub directory not found: $MCP_HUB_DIR"
    fi

    # Check if bridge file exists
    if [[ ! -f "$MCP_HUB_DIR/src/adapters/powerbi-tableau-bridge.ts" ]]; then
        error "PowerBI/Tableau bridge adapter not found"
    fi

    # Build TypeScript if needed
    cd "$MCP_HUB_DIR"
    if [[ ! -f "dist/adapters/powerbi-tableau-bridge.js" ]] || [[ "src/adapters/powerbi-tableau-bridge.ts" -nt "dist/adapters/powerbi-tableau-bridge.js" ]]; then
        log "Building TypeScript..."
        if command -v tsc >/dev/null 2>&1; then
            tsc
        else
            warn "TypeScript compiler not found, attempting to run TypeScript directly with node"
        fi
    fi

    # Check environment variables
    check_environment

    # Start the bridge process
    cd "$MCP_HUB_DIR"
    
    # Use Node.js with --loader for TypeScript if no compiled JS exists
    if [[ -f "dist/adapters/powerbi-tableau-bridge.js" ]]; then
        node dist/adapters/powerbi-tableau-bridge.js > "$LOG_FILE" 2>&1 &
    else
        # Fallback: run TypeScript directly (requires ts-node or similar)
        if command -v tsx >/dev/null 2>&1; then
            tsx src/adapters/powerbi-tableau-bridge.ts > "$LOG_FILE" 2>&1 &
        elif command -v ts-node >/dev/null 2>&1; then
            ts-node src/adapters/powerbi-tableau-bridge.ts > "$LOG_FILE" 2>&1 &
        else
            error "No TypeScript runtime found. Please install tsx or ts-node, or compile to JavaScript first."
        fi
    fi

    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment and check if process started successfully
    sleep 3
    if kill -0 "$pid" 2>/dev/null; then
        log "BI Bridge started successfully (PID: $pid, Port: $BRIDGE_PORT)"
        
        # Wait for server to be ready
        local attempts=0
        while [[ $attempts -lt 10 ]]; do
            if curl -s "http://localhost:$BRIDGE_PORT/api/health" >/dev/null 2>&1; then
                log "Bridge is responding on port $BRIDGE_PORT"
                return 0
            fi
            sleep 1
            ((attempts++))
        done
        
        warn "Bridge started but health check failed"
    else
        rm -f "$PID_FILE"
        error "Failed to start BI Bridge. Check logs: $LOG_FILE"
    fi
}

# Stop the bridge
stop_bridge() {
    if ! is_running; then
        warn "BI Bridge is not running"
        return 0
    fi

    local pid=$(cat "$PID_FILE")
    log "Stopping BI Bridge (PID: $pid)..."
    
    # Try graceful shutdown first
    kill "$pid" 2>/dev/null || true
    
    # Wait up to 10 seconds for graceful shutdown
    local attempts=0
    while [[ $attempts -lt 10 ]] && kill -0 "$pid" 2>/dev/null; do
        sleep 1
        ((attempts++))
    done
    
    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        warn "Graceful shutdown failed, force killing..."
        kill -9 "$pid" 2>/dev/null || true
    fi
    
    rm -f "$PID_FILE"
    log "BI Bridge stopped"
}

# Restart the bridge
restart_bridge() {
    log "Restarting BI Bridge..."
    stop_bridge
    sleep 2
    start_bridge
}

# Show bridge status
show_status() {
    echo -e "${BLUE}=== PowerBI/Tableau Bridge Status ===${NC}"
    
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "Status: ${GREEN}Running${NC} (PID: $pid)"
        
        # Check if port is responding
        if curl -s "http://localhost:$BRIDGE_PORT/api/health" >/dev/null 2>&1; then
            echo -e "Health: ${GREEN}Healthy${NC} (Port: $BRIDGE_PORT)"
            
            # Get bridge info
            local health_info
            health_info=$(curl -s "http://localhost:$BRIDGE_PORT/api/health" 2>/dev/null || echo "{}")
            
            if command -v jq >/dev/null 2>&1; then
                echo "Services:"
                echo "$health_info" | jq -r '.services | to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || echo "  Unable to parse service status"
            else
                echo "Services: (install jq for detailed status)"
            fi
        else
            echo -e "Health: ${RED}Unreachable${NC} (Port: $BRIDGE_PORT)"
        fi
    else
        echo -e "Status: ${RED}Stopped${NC}"
    fi
    
    echo "Port: $BRIDGE_PORT"
    echo "Log File: $LOG_FILE"
    echo "PID File: $PID_FILE"
}

# Check environment configuration
check_environment() {
    log "Checking environment configuration..."
    
    # Check for required environment variables
    local missing_vars=()
    
    # PowerBI configuration
    if [[ -z "${POWERBI_TENANT_ID:-}" ]]; then
        missing_vars+=("POWERBI_TENANT_ID")
    fi
    if [[ -z "${POWERBI_CLIENT_ID:-}" ]]; then
        missing_vars+=("POWERBI_CLIENT_ID")
    fi
    if [[ -z "${POWERBI_CLIENT_SECRET:-}" ]]; then
        missing_vars+=("POWERBI_CLIENT_SECRET")
    fi
    if [[ -z "${POWERBI_WORKSPACE_ID:-}" ]]; then
        missing_vars+=("POWERBI_WORKSPACE_ID")
    fi
    
    # Tableau configuration
    if [[ -z "${TABLEAU_SERVER_URL:-}" ]]; then
        missing_vars+=("TABLEAU_SERVER_URL")
    fi
    if [[ -z "${TABLEAU_USERNAME:-}" ]]; then
        missing_vars+=("TABLEAU_USERNAME")
    fi
    if [[ -z "${TABLEAU_PASSWORD:-}" ]]; then
        missing_vars+=("TABLEAU_PASSWORD")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required environment variables: ${missing_vars[*]}"
    fi
    
    log "Environment configuration looks good"
}

# View logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${BLUE}=== BI Bridge Logs ===${NC}"
        tail -n 50 "$LOG_FILE"
    else
        warn "No log file found at $LOG_FILE"
    fi
}

# Test bridge connectivity
test_bridge() {
    log "Testing BI Bridge connectivity..."
    
    if ! is_running; then
        error "BI Bridge is not running. Start it first with: $0 start"
    fi
    
    # Test health endpoint
    log "Testing health endpoint..."
    if ! curl -s "http://localhost:$BRIDGE_PORT/api/health" >/dev/null; then
        error "Health endpoint not responding"
    fi
    
    # Test PowerBI endpoints
    log "Testing PowerBI endpoints..."
    if ! curl -s "http://localhost:$BRIDGE_PORT/api/powerbi/dashboards" >/dev/null; then
        warn "PowerBI dashboards endpoint not responding"
    fi
    
    # Test Tableau endpoints  
    log "Testing Tableau endpoints..."
    if ! curl -s "http://localhost:$BRIDGE_PORT/api/tableau/workbooks" >/dev/null; then
        warn "Tableau workbooks endpoint not responding"
    fi
    
    # Test BI overview
    log "Testing BI overview..."
    local overview
    overview=$(curl -s "http://localhost:$BRIDGE_PORT/api/bi/overview" 2>/dev/null || echo "{}")
    
    if command -v jq >/dev/null 2>&1; then
        echo -e "${BLUE}=== BI Overview ===${NC}"
        echo "$overview" | jq . 2>/dev/null || echo "Unable to parse overview"
    fi
    
    log "Bridge connectivity tests completed"
}

# Install/setup bridge
install_bridge() {
    log "Installing BI Bridge dependencies..."
    
    cd "$MCP_HUB_DIR"
    
    # Install Node.js dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        log "Installing npm dependencies..."
        npm install
    fi
    
    # Install additional BI-specific dependencies if needed
    # (PowerBI and Tableau SDKs would be installed via npm)
    
    log "Creating environment template..."
    cat > .env.bi.template << 'EOF'
# PowerBI Configuration
POWERBI_TENANT_ID=your_tenant_id_here
POWERBI_CLIENT_ID=your_client_id_here
POWERBI_CLIENT_SECRET=your_client_secret_here
POWERBI_WORKSPACE_ID=your_workspace_id_here
POWERBI_API_URL=https://api.powerbi.com

# Tableau Configuration
TABLEAU_SERVER_URL=https://your-tableau-server.com
TABLEAU_SITE_NAME=your_site_name
TABLEAU_USERNAME=your_username
TABLEAU_PASSWORD=your_password
TABLEAU_API_VERSION=3.18

# Bridge Configuration
BRIDGE_PORT=3002
EOF
    
    log "BI Bridge installation completed"
    log "Please configure environment variables in .env.bi.template"
}

# Show usage
usage() {
    echo -e "${BLUE}PowerBI/Tableau Bridge Management${NC}"
    echo
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  start     - Start the BI bridge"
    echo "  stop      - Stop the BI bridge" 
    echo "  restart   - Restart the BI bridge"
    echo "  status    - Show bridge status"
    echo "  logs      - Show bridge logs"
    echo "  test      - Test bridge connectivity"
    echo "  install   - Install/setup bridge"
    echo "  help      - Show this help message"
    echo
    echo "Environment Variables:"
    echo "  BRIDGE_PORT - Port to run bridge on (default: 3002)"
    echo
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 status"
    echo "  BRIDGE_PORT=3003 $0 start"
}

# Main command handling
case "${1:-help}" in
    start)
        start_bridge
        ;;
    stop)
        stop_bridge
        ;;
    restart)
        restart_bridge
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    test)
        test_bridge
        ;;
    install)
        install_bridge
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo
        usage
        exit 1
        ;;
esac