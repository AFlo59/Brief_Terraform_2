#!/bin/bash
# =============================================================================
# Logs Script - Voir les logs du pipeline
# =============================================================================
# Usage: ./logs.sh [--service pipeline] [--follow] [--lines 100]
# =============================================================================

SERVICE="pipeline"
FOLLOW=false
LINES=100

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --service|-s)
            SERVICE="$2"
            shift 2
            ;;
        --follow|-f)
            FOLLOW=true
            shift
            ;;
        --lines|-n)
            LINES="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -s, --service    Service: pipeline, postgres, azurite, pgadmin, all"
            echo "  -f, --follow     Suivre les logs en temps réel"
            echo "  -n, --lines      Nombre de lignes (défaut: 100)"
            echo "  -h, --help       Afficher cette aide"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")/docker"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"

LOG_ARGS="-f $COMPOSE_FILE logs"

if [ "$FOLLOW" = true ]; then
    LOG_ARGS="$LOG_ARGS -f"
fi

LOG_ARGS="$LOG_ARGS --tail $LINES"

if [ "$SERVICE" != "all" ]; then
    LOG_ARGS="$LOG_ARGS $SERVICE"
fi

echo -e "${GREEN}[INFO]${NC} Affichage des logs: $SERVICE"
docker compose $LOG_ARGS
