#!/bin/bash
# Environment configuration manager for Scout Analytics Platform

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environments"

# Current environment file
ENV_FILE="$PROJECT_ROOT/.current-env"

usage() {
    cat <<EOF
Usage: $0 [command] [environment]

Commands:
    list        List all available environments
    show        Show current environment
    switch      Switch to a different environment
    diff        Compare two environments
    validate    Validate environment configuration
    export      Export environment variables
    import      Import environment from vault

Examples:
    $0 list
    $0 switch staging
    $0 diff dev prod
    $0 validate prod
    $0 export prod > prod.env

EOF
    exit 1
}

list_environments() {
    echo -e "${BLUE}Available environments:${NC}"
    for env in "$ENV_DIR"/*; do
        if [ -d "$env" ]; then
            env_name=$(basename "$env")
            if [ -f "$ENV_FILE" ] && [ "$(cat "$ENV_FILE")" = "$env_name" ]; then
                echo -e "  ${GREEN}* $env_name (current)${NC}"
            else
                echo "  - $env_name"
            fi
        fi
    done
}

show_current() {
    if [ -f "$ENV_FILE" ]; then
        current=$(cat "$ENV_FILE")
        echo -e "${GREEN}Current environment: $current${NC}"
        echo ""
        echo "Configuration files:"
        ls -la "$ENV_DIR/$current/" 2>/dev/null | grep -E '\.(yaml|env)$' | awk '{print "  - " $9}'
    else
        echo -e "${YELLOW}No environment currently selected${NC}"
        echo "Run: $0 switch <environment>"
    fi
}

switch_environment() {
    local new_env=$1
    
    if [ ! -d "$ENV_DIR/$new_env" ]; then
        echo -e "${RED}Error: Environment '$new_env' not found${NC}"
        list_environments
        exit 1
    fi
    
    # Check for required files
    local missing=()
    for file in values.yaml superset.env edge.env; do
        if [ ! -f "$ENV_DIR/$new_env/$file" ]; then
            missing+=("$file")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: Missing files in $new_env environment:${NC}"
        printf '  - %s\n' "${missing[@]}"
    fi
    
    # Check for secrets
    if [ ! -f "$ENV_DIR/$new_env/secrets.yaml" ]; then
        if [ -f "$ENV_DIR/$new_env/secrets.yaml.example" ]; then
            echo -e "${YELLOW}Note: No secrets.yaml found. Copy from secrets.yaml.example:${NC}"
            echo "  cp $ENV_DIR/$new_env/secrets.yaml.example $ENV_DIR/$new_env/secrets.yaml"
        fi
    fi
    
    # Save current environment
    echo "$new_env" > "$ENV_FILE"
    
    # Create .env symlinks
    ln -sf "$ENV_DIR/$new_env/edge.env" "$PROJECT_ROOT/.env"
    ln -sf "$ENV_DIR/$new_env/superset.env" "$PROJECT_ROOT/.env.superset"
    
    echo -e "${GREEN}✓ Switched to $new_env environment${NC}"
    echo ""
    echo "To load environment variables:"
    echo "  source .env"
    echo ""
    echo "To deploy:"
    echo "  make deploy-env ENVIRONMENT=$new_env"
}

diff_environments() {
    local env1=$1
    local env2=$2
    
    if [ ! -d "$ENV_DIR/$env1" ] || [ ! -d "$ENV_DIR/$env2" ]; then
        echo -e "${RED}Error: Both environments must exist${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Comparing $env1 vs $env2:${NC}"
    echo ""
    
    for file in values.yaml superset.env edge.env; do
        if [ -f "$ENV_DIR/$env1/$file" ] && [ -f "$ENV_DIR/$env2/$file" ]; then
            echo -e "${YELLOW}=== $file ===${NC}"
            diff -u "$ENV_DIR/$env1/$file" "$ENV_DIR/$env2/$file" || true
            echo ""
        fi
    done
}

validate_environment() {
    local env=$1
    
    if [ ! -d "$ENV_DIR/$env" ]; then
        echo -e "${RED}Error: Environment '$env' not found${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Validating $env environment...${NC}"
    
    local errors=0
    
    # Check required files
    for file in values.yaml superset.env edge.env; do
        if [ -f "$ENV_DIR/$env/$file" ]; then
            echo -e "  ${GREEN}✓${NC} $file exists"
        else
            echo -e "  ${RED}✗${NC} $file missing"
            ((errors++))
        fi
    done
    
    # Validate YAML syntax
    if command -v yq >/dev/null 2>&1; then
        if [ -f "$ENV_DIR/$env/values.yaml" ]; then
            if yq eval . "$ENV_DIR/$env/values.yaml" >/dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} values.yaml syntax valid"
            else
                echo -e "  ${RED}✗${NC} values.yaml has syntax errors"
                ((errors++))
            fi
        fi
    fi
    
    # Check for placeholder values
    if [ -f "$ENV_DIR/$env/edge.env" ]; then
        if grep -q '\${[A-Z_]*}' "$ENV_DIR/$env/edge.env"; then
            echo -e "  ${YELLOW}!${NC} edge.env contains variable placeholders"
            grep '\${[A-Z_]*}' "$ENV_DIR/$env/edge.env" | sed 's/^/    /'
        fi
    fi
    
    if [ -f "$ENV_DIR/$env/superset.env" ]; then
        if grep -q '\${[A-Z_]*}' "$ENV_DIR/$env/superset.env"; then
            echo -e "  ${YELLOW}!${NC} superset.env contains variable placeholders"
            grep '\${[A-Z_]*}' "$ENV_DIR/$env/superset.env" | sed 's/^/    /'
        fi
    fi
    
    # Check secrets
    if [ -f "$ENV_DIR/$env/secrets.yaml" ]; then
        echo -e "  ${GREEN}✓${NC} secrets.yaml exists"
        if [ "$env" = "prod" ]; then
            if grep -q 'vault' "$ENV_DIR/$env/secrets.yaml" || grep -q '\${' "$ENV_DIR/$env/secrets.yaml"; then
                echo -e "  ${GREEN}✓${NC} Production secrets use vault references"
            else
                echo -e "  ${YELLOW}!${NC} Production secrets should use vault references"
            fi
        fi
    else
        echo -e "  ${YELLOW}!${NC} secrets.yaml missing (copy from secrets.yaml.example)"
    fi
    
    if [ $errors -gt 0 ]; then
        echo -e "\n${RED}Validation failed with $errors errors${NC}"
        exit 1
    else
        echo -e "\n${GREEN}✓ Environment $env is valid${NC}"
    fi
}

export_environment() {
    local env=$1
    
    if [ ! -d "$ENV_DIR/$env" ]; then
        echo -e "${RED}Error: Environment '$env' not found${NC}" >&2
        exit 1
    fi
    
    echo "# Scout Analytics Platform - $env environment"
    echo "# Generated: $(date)"
    echo ""
    
    # Export edge.env
    if [ -f "$ENV_DIR/$env/edge.env" ]; then
        echo "# === Edge Functions Configuration ==="
        grep -v '^#' "$ENV_DIR/$env/edge.env" | grep -v '^$'
        echo ""
    fi
    
    # Export superset.env (excluding sensitive values)
    if [ -f "$ENV_DIR/$env/superset.env" ]; then
        echo "# === Superset Configuration ==="
        grep -v '^#' "$ENV_DIR/$env/superset.env" | grep -v '^$' | \
            sed 's/PASSWORD=.*/PASSWORD=<REDACTED>/' | \
            sed 's/SECRET_KEY=.*/SECRET_KEY=<REDACTED>/'
        echo ""
    fi
}

# Main command handling
case "${1:-}" in
    list)
        list_environments
        ;;
    show)
        show_current
        ;;
    switch)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Environment name required${NC}"
            usage
        fi
        switch_environment "$2"
        ;;
    diff)
        if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
            echo -e "${RED}Error: Two environment names required${NC}"
            usage
        fi
        diff_environments "$2" "$3"
        ;;
    validate)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Environment name required${NC}"
            usage
        fi
        validate_environment "$2"
        ;;
    export)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Environment name required${NC}"
            usage
        fi
        export_environment "$2"
        ;;
    *)
        usage
        ;;
esac