#!/bin/bash

# MLOps Monitoring Suite - Run All Components
# Comprehensive monitoring for Scout Dashboard AI systems

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOGS_DIR="$PROJECT_ROOT/logs/mlops"
VENV_DIR="$PROJECT_ROOT/.venv"
PID_DIR="/tmp/mlops-monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  echo -e "${GREEN}[INFO]${NC}  ${timestamp} - $message" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC}  ${timestamp} - $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} ${timestamp} - $message" ;;
        DEBUG) echo -e "${BLUE}[DEBUG]${NC} ${timestamp} - $message" ;;
    esac
    
    # Also write to log file
    echo "[$level] $timestamp - $message" >> "$LOGS_DIR/mlops-monitoring.log"
}

# Setup directories
setup_directories() {
    log INFO "Setting up MLOps monitoring directories..."
    
    mkdir -p "$LOGS_DIR"
    mkdir -p "$PID_DIR"
    
    # Clear old logs (keep last 7 days)
    find "$LOGS_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    log INFO "Directories setup complete"
}

# Setup Python virtual environment
setup_python_env() {
    log INFO "Setting up Python environment..."
    
    if [[ ! -d "$VENV_DIR" ]]; then
        log INFO "Creating Python virtual environment..."
        python3 -m venv "$VENV_DIR"
    fi
    
    source "$VENV_DIR/bin/activate"
    
    # Install required packages
    pip install -q --upgrade pip
    pip install -q asyncpg psutil requests jinja2 smtplib email-mime scipy numpy
    
    log INFO "Python environment ready"
}

# Check required environment variables
check_environment() {
    log INFO "Checking environment variables..."
    
    local required_vars=(
        "DATABASE_URL"
        "SUPABASE_PROJECT_REF" 
        "SUPABASE_SERVICE_ROLE_KEY"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log ERROR "Missing required environment variables:"
        printf '%s\n' "${missing_vars[@]}"
        log ERROR "Please set these variables and try again"
        exit 1
    fi
    
    log INFO "Environment check passed"
}

# Start cost monitoring
start_cost_monitoring() {
    log INFO "Starting cost monitoring..."
    
    local cost_script="$SCRIPT_DIR/mlops-cost-monitor.py"
    local cost_log="$LOGS_DIR/cost-monitor.log"
    local cost_pid="$PID_DIR/cost-monitor.pid"
    
    if [[ -f "$cost_script" ]]; then
        nohup python3 "$cost_script" >> "$cost_log" 2>&1 &
        local pid=$!
        echo $pid > "$cost_pid"
        log INFO "Cost monitoring started (PID: $pid)"
    else
        log WARN "Cost monitoring script not found: $cost_script"
    fi
}

# Start drift detection
start_drift_detection() {
    log INFO "Starting drift detection..."
    
    local drift_script="$SCRIPT_DIR/mlops-drift-detector.py"
    local drift_log="$LOGS_DIR/drift-detector.log"
    local drift_pid="$PID_DIR/drift-detector.pid"
    
    if [[ -f "$drift_script" ]]; then
        nohup python3 "$drift_script" >> "$drift_log" 2>&1 &
        local pid=$!
        echo $pid > "$drift_pid"
        log INFO "Drift detection started (PID: $pid)"
    else
        log WARN "Drift detection script not found: $drift_script"
    fi
}

# Generate model cards
generate_model_cards() {
    log INFO "Generating model cards..."
    
    local cards_script="$SCRIPT_DIR/model-card-generator.py"
    
    if [[ -f "$cards_script" ]]; then
        python3 "$cards_script"
        log INFO "Model cards generation completed"
    else
        log WARN "Model cards generator script not found: $cards_script"
    fi
}

# Check service health
check_service_health() {
    log INFO "Checking service health..."
    
    # Check if processes are running
    local services=("cost-monitor" "drift-detector")
    local healthy=0
    
    for service in "${services[@]}"; do
        local pid_file="$PID_DIR/$service.pid"
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                log INFO "Service $service is running (PID: $pid)"
                ((healthy++))
            else
                log WARN "Service $service is not running (stale PID file)"
                rm -f "$pid_file"
            fi
        else
            log WARN "Service $service is not running (no PID file)"
        fi
    done
    
    log INFO "Health check complete: $healthy/${#services[@]} services running"
    
    # Check database connectivity
    if python3 -c "
import asyncio
import asyncpg
import os

async def test_db():
    try:
        conn = await asyncpg.connect(os.getenv('DATABASE_URL'))
        result = await conn.fetchval('SELECT 1')
        await conn.close()
        print('Database: OK')
    except Exception as e:
        print(f'Database: ERROR - {e}')
        exit(1)

asyncio.run(test_db())
    "; then
        log INFO "Database connectivity: OK"
    else
        log ERROR "Database connectivity: FAILED"
        return 1
    fi
}

# Stop all monitoring services
stop_monitoring() {
    log INFO "Stopping MLOps monitoring services..."
    
    local services=("cost-monitor" "drift-detector")
    
    for service in "${services[@]}"; do
        local pid_file="$PID_DIR/$service.pid"
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                log INFO "Stopping $service (PID: $pid)..."
                kill "$pid"
                
                # Wait for graceful shutdown
                local count=0
                while kill -0 "$pid" 2>/dev/null && [[ $count -lt 30 ]]; do
                    sleep 1
                    ((count++))
                done
                
                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    log WARN "Force killing $service..."
                    kill -9 "$pid"
                fi
                
                rm -f "$pid_file"
                log INFO "Service $service stopped"
            else
                log INFO "Service $service was not running"
                rm -f "$pid_file"
            fi
        fi
    done
    
    log INFO "All monitoring services stopped"
}

# Show monitoring status
show_status() {
    log INFO "MLOps Monitoring Status"
    echo "=========================="
    
    # Service status
    local services=("cost-monitor" "drift-detector")
    for service in "${services[@]}"; do
        local pid_file="$PID_DIR/$service.pid"
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${service}: ${GREEN}RUNNING${NC} (PID: $pid)"
            else
                echo -e "${service}: ${RED}STOPPED${NC} (stale PID)"
            fi
        else
            echo -e "${service}: ${RED}STOPPED${NC}"
        fi
    done
    
    echo ""
    
    # Recent logs
    echo "Recent Activity:"
    echo "----------------"
    if [[ -f "$LOGS_DIR/mlops-monitoring.log" ]]; then
        tail -5 "$LOGS_DIR/mlops-monitoring.log"
    else
        echo "No recent activity"
    fi
    
    echo ""
    
    # Database stats
    echo "Database Stats (last 24h):"
    echo "---------------------------"
    python3 -c "
import asyncio
import asyncpg
import os
from datetime import datetime, timedelta

async def get_stats():
    try:
        conn = await asyncpg.connect(os.getenv('DATABASE_URL'))
        
        # Model performance count
        count = await conn.fetchval('''
            SELECT COUNT(*) FROM mlops.model_performance 
            WHERE created_at >= NOW() - INTERVAL '24 hours'
        ''')
        print(f'Model performance records: {count}')
        
        # Drift alerts
        alerts = await conn.fetchval('''
            SELECT COUNT(*) FROM mlops.drift_detection 
            WHERE detected_at >= NOW() - INTERVAL '24 hours'
        ''')
        print(f'Drift alerts: {alerts}')
        
        # Total cost
        cost = await conn.fetchval('''
            SELECT COALESCE(SUM(estimated_cost_usd), 0) FROM mlops.model_performance 
            WHERE created_at >= NOW() - INTERVAL '24 hours'
        ''')
        print(f'Total cost: ${cost:.6f}')
        
        await conn.close()
    except Exception as e:
        print(f'Database error: {e}')

asyncio.run(get_stats())
    " || echo "Could not fetch database stats"
}

# Main function
main() {
    local action="${1:-start}"
    
    echo -e "${BLUE}Scout Dashboard MLOps Monitoring Suite${NC}"
    echo "======================================"
    
    case $action in
        start)
            setup_directories
            check_environment
            setup_python_env
            
            source "$VENV_DIR/bin/activate"
            
            start_cost_monitoring
            start_drift_detection
            generate_model_cards
            
            sleep 2
            check_service_health
            
            log INFO "MLOps monitoring suite started successfully"
            log INFO "Run '$0 status' to check service status"
            log INFO "Run '$0 stop' to stop all services"
            ;;
            
        stop)
            stop_monitoring
            ;;
            
        status)
            show_status
            ;;
            
        restart)
            stop_monitoring
            sleep 2
            main start
            ;;
            
        health)
            setup_python_env
            source "$VENV_DIR/bin/activate"
            check_service_health
            ;;
            
        cards)
            setup_python_env
            source "$VENV_DIR/bin/activate"
            check_environment
            generate_model_cards
            ;;
            
        *)
            echo "Usage: $0 {start|stop|status|restart|health|cards}"
            echo ""
            echo "Commands:"
            echo "  start   - Start all MLOps monitoring services"
            echo "  stop    - Stop all MLOps monitoring services"
            echo "  status  - Show status of all services"
            echo "  restart - Restart all services"
            echo "  health  - Run health checks"
            echo "  cards   - Generate model cards only"
            exit 1
            ;;
    esac
}

# Trap for cleanup
trap 'echo ""; log INFO "Caught signal, cleaning up..."; stop_monitoring; exit 1' INT TERM

# Run main function
main "$@"