#!/bin/bash
set -euo pipefail

# TBWA Figma Bridge CLI Helper
# Enables write operations in Figma via Claude Code CLI
#
# Usage:
#   ./scripts/figma.sh status                    # Check bridge status
#   ./scripts/figma.sh start                     # Start MCP Hub bridge
#   ./scripts/figma.sh sticky "Meeting notes"    # Create FigJam sticky
#   ./scripts/figma.sh frame "Dashboard" 800 600 # Create Figma frame
#   ./scripts/figma.sh dashboard "Q4 Review"     # Create dashboard layout

# Configuration
BRIDGE_HOST="localhost"
BRIDGE_PORT="8787"
BRIDGE_URL="ws://${BRIDGE_HOST}:${BRIDGE_PORT}/figma-bridge"
MCP_HUB_PID_FILE="/tmp/figma-mcp-hub.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[Figma Bridge]${NC} $1"; }
warn() { echo -e "${YELLOW}[Warning]${NC} $1"; }
error() { echo -e "${RED}[Error]${NC} $1"; }

# Check if MCP Hub is running
check_mcp_hub() {
    if [ -f "$MCP_HUB_PID_FILE" ]; then
        local pid=$(cat "$MCP_HUB_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            rm -f "$MCP_HUB_PID_FILE"
            return 1  # Not running
        fi
    else
        return 1  # Not running
    fi
}

# Start MCP Hub with Figma Bridge
start_bridge() {
    if check_mcp_hub; then
        log "MCP Hub already running (PID: $(cat $MCP_HUB_PID_FILE))"
        return 0
    fi

    log "Starting MCP Hub with Figma Bridge..."
    
    # Check if Node.js is available
    if ! command -v node >/dev/null 2>&1; then
        error "Node.js is required but not installed"
        return 1
    fi

    # Check if MCP Hub exists
    local hub_path="/Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub"
    if [ ! -d "$hub_path" ]; then
        error "MCP Hub not found at $hub_path"
        return 1
    fi

    # Start in background
    cd "$hub_path"
    nohup node -e "
        const { FigmaBridge } = require('./dist/adapters/figma-bridge.js');
        
        const bridge = new FigmaBridge({
            port: $BRIDGE_PORT,
            timeout: 30000,
            maxClients: 5
        });

        bridge.on('client_connected', (data) => {
            console.log('✅ Figma plugin connected (' + data.clientCount + ' clients)');
        });

        bridge.on('client_disconnected', (data) => {
            console.log('🔌 Figma plugin disconnected (' + data.clientCount + ' clients remaining)');
        });

        bridge.on('usage_log', (data) => {
            console.log('📊 Usage logged:', data);
        });

        console.log('🎨 Figma Bridge ready at $BRIDGE_URL');
        console.log('📝 Install plugin from creative-studio/figma-bridge-plugin/');
        
        process.on('SIGTERM', () => {
            console.log('🛑 Shutting down Figma Bridge...');
            bridge.close();
            process.exit(0);
        });
    " > /tmp/figma-mcp-hub.log 2>&1 &

    local pid=$!
    echo "$pid" > "$MCP_HUB_PID_FILE"
    
    # Give it a moment to start
    sleep 2
    
    if kill -0 "$pid" 2>/dev/null; then
        log "MCP Hub started successfully (PID: $pid)"
        log "WebSocket endpoint: $BRIDGE_URL"
        log "Install Figma plugin from: creative-studio/figma-bridge-plugin/"
        return 0
    else
        error "Failed to start MCP Hub"
        rm -f "$MCP_HUB_PID_FILE"
        return 1
    fi
}

# Stop MCP Hub
stop_bridge() {
    if check_mcp_hub; then
        local pid=$(cat "$MCP_HUB_PID_FILE")
        log "Stopping MCP Hub (PID: $pid)..."
        kill "$pid"
        rm -f "$MCP_HUB_PID_FILE"
        log "MCP Hub stopped"
    else
        warn "MCP Hub is not running"
    fi
}

# Get bridge status
get_status() {
    log "Figma Bridge Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if check_mcp_hub; then
        echo -e "MCP Hub:        ${GREEN}✅ Running${NC} (PID: $(cat $MCP_HUB_PID_FILE))"
        echo -e "WebSocket:      ${BLUE}$BRIDGE_URL${NC}"
    else
        echo -e "MCP Hub:        ${RED}❌ Stopped${NC}"
        echo -e "WebSocket:      ${RED}Unavailable${NC}"
    fi
    
    # Test WebSocket connection
    if command -v wscat >/dev/null 2>&1; then
        if timeout 3 wscat -c "$BRIDGE_URL" --no-interaction >/dev/null 2>&1; then
            echo -e "Connection:     ${GREEN}✅ Reachable${NC}"
        else
            echo -e "Connection:     ${RED}❌ Failed${NC}"
        fi
    else
        echo -e "Connection:     ${YELLOW}? (install wscat to test)${NC}"
    fi
    
    # Check plugin files
    local plugin_dir="/Users/tbwa/ai-aas-hardened-lakehouse/creative-studio/figma-bridge-plugin"
    if [ -f "$plugin_dir/manifest.json" ]; then
        echo -e "Plugin Files:   ${GREEN}✅ Available${NC}"
        echo -e "Plugin Path:    ${BLUE}$plugin_dir${NC}"
    else
        echo -e "Plugin Files:   ${RED}❌ Missing${NC}"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! check_mcp_hub; then
        echo ""
        echo "To start the bridge:"
        echo "  $0 start"
        echo ""
        echo "To install the Figma plugin:"
        echo "  1. Open Figma Desktop"
        echo "  2. Go to Plugins → Development → Import plugin from manifest"
        echo "  3. Select: $plugin_dir/manifest.json"
    fi
}

# Send command via WebSocket (requires wscat)
send_command() {
    local command="$1"
    
    if ! command -v wscat >/dev/null 2>&1; then
        error "wscat is required for sending commands. Install with: npm install -g wscat"
        return 1
    fi
    
    if ! check_mcp_hub; then
        error "MCP Hub is not running. Start it with: $0 start"
        return 1
    fi
    
    log "Sending command: $command"
    echo "$command" | wscat -c "$BRIDGE_URL" -w 5
}

# Create FigJam sticky note
create_sticky() {
    local text="${1:-Sample sticky note}"
    local color="${2:-yellow}"
    
    local cmd="{\"type\": \"create-sticky\", \"text\": \"$text\", \"color\": \"$color\"}"
    send_command "$cmd"
}

# Create Figma frame
create_frame() {
    local name="${1:-New Frame}"
    local width="${2:-400}"
    local height="${3:-300}"
    
    local cmd="{\"type\": \"create-frame\", \"name\": \"$name\", \"width\": $width, \"height\": $height}"
    send_command "$cmd"
}

# Create dashboard layout
create_dashboard() {
    local title="${1:-Dashboard}"
    
    # Sample dashboard layout
    local cmd="{
        \"type\": \"create-dashboard-layout\",
        \"title\": \"$title\",
        \"grid\": {\"cols\": 4, \"gutter\": 16},
        \"tiles\": [
            {\"id\": \"kpi1\", \"type\": \"metric\", \"x\": 0, \"y\": 0, \"w\": 1, \"h\": 1},
            {\"id\": \"chart1\", \"type\": \"line\", \"x\": 1, \"y\": 0, \"w\": 3, \"h\": 2},
            {\"id\": \"table1\", \"type\": \"table\", \"x\": 0, \"y\": 2, \"w\": 4, \"h\": 2}
        ]
    }"
    
    send_command "$cmd"
}

# Install plugin helper
install_plugin() {
    local plugin_dir="/Users/tbwa/ai-aas-hardened-lakehouse/creative-studio/figma-bridge-plugin"
    
    log "Figma Plugin Installation Instructions:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Open Figma Desktop application"
    echo "2. Go to: Plugins → Development → Import plugin from manifest..."
    echo "3. Navigate to and select:"
    echo -e "   ${BLUE}$plugin_dir/manifest.json${NC}"
    echo "4. The plugin will appear in your Plugins menu as 'TBWA Creative Bridge'"
    echo "5. Run the plugin to establish WebSocket connection"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "The plugin will automatically connect to the MCP Hub at:"
    echo -e "${BLUE}$BRIDGE_URL${NC}"
    
    if [ -f "$plugin_dir/manifest.json" ]; then
        echo -e "\n${GREEN}✅ Plugin files are ready${NC}"
    else
        echo -e "\n${RED}❌ Plugin files not found${NC}"
        error "Run this script from the repository root"
    fi
}

# Show help
show_help() {
    echo "TBWA Figma Bridge CLI Helper"
    echo "Enables write operations in Figma via Claude Code CLI"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status                          Show bridge status"
    echo "  start                           Start MCP Hub bridge"
    echo "  stop                            Stop MCP Hub bridge"
    echo "  install                         Show plugin installation instructions"
    echo ""
    echo "Figma Commands (requires running bridge & plugin):"
    echo "  sticky <text> [color]           Create FigJam sticky note"
    echo "  frame <name> [width] [height]   Create Figma frame"
    echo "  dashboard <title>               Create dashboard layout"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 sticky 'Sprint retrospective' blue"
    echo "  $0 frame 'Mobile mockup' 375 812"
    echo "  $0 dashboard 'Q4 Analytics'"
    echo ""
    echo "Setup:"
    echo "  1. Run: $0 start"
    echo "  2. Run: $0 install (follow instructions)"
    echo "  3. Use Claude Code CLI with write operations enabled"
}

# Main command handler
main() {
    local command="${1:-help}"
    
    case "$command" in
        "status")
            get_status
            ;;
        "start")
            start_bridge
            ;;
        "stop")
            stop_bridge
            ;;
        "restart")
            stop_bridge
            sleep 1
            start_bridge
            ;;
        "install")
            install_plugin
            ;;
        "sticky")
            create_sticky "${2:-}" "${3:-}"
            ;;
        "frame")
            create_frame "${2:-}" "${3:-}" "${4:-}"
            ;;
        "dashboard")
            create_dashboard "${2:-}"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"