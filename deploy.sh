#!/bin/bash

# Home Server Management Script
# Usage: ./deploy.sh [command] [service]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service directories
SERVICES=(
    "infrastructure"
    "media" 
    "productivity"
)

print_usage() {
    echo -e "${BLUE}Home Server Management Script${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [SERVICE]"
    echo ""
    echo "Commands:"
    echo "  setup     - Initial setup (create networks and directories)"
    echo "  start     - Start services"
    echo "  stop      - Stop services"
    echo "  restart   - Restart services"
    echo "  logs      - Show logs"
    echo "  status    - Show status"
    echo "  update    - Pull latest images and restart"
    echo "  cleanup   - Remove stopped containers and unused images"
    echo ""
    echo "Services:"
    echo "  all           - All services"
    echo "  infrastructure - DNS and reverse proxy"
    echo "  media         - Plex, Sonarr, Radarr, etc."
    echo "  productivity  - Plane, SilverBullet"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 start all"
    echo "  $0 start media"
    echo "  $0 logs productivity"
    echo "  $0 update plane"
}

setup() {
    echo -e "${GREEN}Setting up home server environment...${NC}"
    
    # Create shared network
    echo "Creating shared network..."
    docker network create shared-network 2>/dev/null || echo "Network already exists"
    
    # Create directory structure
    echo "Creating directory structure..."
    mkdir -p {infrastructure,media,productivity}/config
    
    # Media directories
    mkdir -p media/config/{deluge,plex,sonarr,radarr,prowlarr,threadfin}
    
    # Productivity directories  
    mkdir -p productivity/{space,config/plane/{redis-data,pgdata,uploads,logs}}
    
    # Infrastructure directories (Caddy)
    mkdir -p infrastructure/config/{caddy/{data,config,sites},ssl}
    
    # Set proper permissions for Plane
    echo "Setting permissions..."
    chmod -R 755 productivity/config/plane/
    chown -R 1000:1000 productivity/config/plane/ 2>/dev/null || true
    
    echo -e "${GREEN}Setup completed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Copy your existing config files to the new structure"
    echo "2. Update IP addresses in configs if needed" 
    echo "3. Run: $0 start infrastructure"
    echo "4. Run: $0 start media"
    echo "5. Run: $0 start productivity"
}

run_docker_compose() {
    local command=$1
    local service=$2
    local extra_args=${3:-""}
    
    case $service in
        "all")
            for svc in "${SERVICES[@]}"; do
                if [ -d "$svc" ]; then
                    echo -e "${BLUE}${command^} $svc...${NC}"
                    (cd "$svc" && docker-compose $command $extra_args)
                fi
            done
            ;;
        "infrastructure"|"media"|"productivity")
            if [ -d "$service" ]; then
                echo -e "${BLUE}${command^} $service...${NC}"
                (cd "$service" && docker-compose $command $extra_args)
            else
                echo -e "${RED}Service directory '$service' not found${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            print_usage
            exit 1
            ;;
    esac
}

case "${1:-}" in
    "setup")
        setup
        ;;
    "start")
        run_docker_compose "up -d" "${2:-all}"
        ;;
    "stop") 
        run_docker_compose "down" "${2:-all}"
        ;;
    "restart")
        run_docker_compose "restart" "${2:-all}"
        ;;
    "logs")
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Please specify a service for logs${NC}"
            exit 1
        fi
        run_docker_compose "logs -f" "${2}"
        ;;
    "status")
        run_docker_compose "ps" "${2:-all}"
        ;;
    "update")
        echo -e "${GREEN}Updating services...${NC}"
        run_docker_compose "pull" "${2:-all}"
        run_docker_compose "up -d" "${2:-all}"
        ;;
    "cleanup")
        echo -e "${YELLOW}Cleaning up Docker resources...${NC}"
        docker container prune -f
        docker image prune -f
        docker volume prune -f
        docker network prune -f
        echo -e "${GREEN}Cleanup completed${NC}"
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
