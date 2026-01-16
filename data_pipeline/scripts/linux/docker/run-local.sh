#!/bin/bash
# =============================================================================
# Run Local Script - Data Pipeline avec émulateurs locaux
# =============================================================================
# Lance le pipeline en mode local avec PostgreSQL et Azurite
# Usage: ./run-local.sh [options]
# =============================================================================

set -e

# Configuration par défaut
START_DATE="2024-01"
END_DATE="2024-01"
MODE="all"
DETACH=false
WITH_TOOLS=false

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
DOCKER_DIR="$PROJECT_ROOT/docker"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

# Vérifier si Docker tourne
check_docker_running() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker n'est pas en cours d'exécution!"
        echo -e "${YELLOW}[INFO]${NC} Lancez Docker Desktop et réessayez."
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} Docker est en cours d'exécution"
}

# Vérifier si l'image existe
check_image() {
    if ! docker image inspect "nyc-taxi-pipeline:latest" &>/dev/null; then
        echo -e "${YELLOW}[WARNING]${NC} Image non trouvée. Construction..."
        "$SCRIPT_DIR/build.sh" --auto
    fi
}

# Afficher le statut
show_status() {
    echo -e "${CYAN}[STATUS]${NC} Services actuels:"
    
    local running=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l)
    if [ "$running" -gt 0 ]; then
        echo -e "  ${GREEN}$running service(s) actif(s)${NC}"
        docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tail -n +2 | while read line; do
            echo "    $line"
        done
    else
        echo -e "  ${YELLOW}Aucun service actif${NC}"
    fi
    echo ""
}

# Afficher le menu
show_menu() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Run Local - NYC Taxi Data Pipeline                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    show_status
    echo -e "${CYAN}Configuration actuelle:${NC}"
    echo "  - Période: $START_DATE → $END_DATE"
    echo "  - Mode: $MODE"
    echo ""
    echo -e "${CYAN}Choisissez une option :${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Lancer le pipeline (interactif)"
    echo -e "  ${BLUE}2)${NC} Lancer en arrière-plan"
    echo -e "  ${CYAN}3)${NC} Lancer avec PgAdmin (outil DB)"
    echo -e "  ${YELLOW}4)${NC} Configurer la période/mode"
    echo ""
    echo -e "  ${RED}q)${NC} Quitter"
    echo ""
}

# Configuration interactive
configure_pipeline() {
    echo ""
    echo -e "${CYAN}[CONFIG]${NC} Configuration du pipeline"
    echo ""
    
    read -p "Date de début (YYYY-MM) [$START_DATE]: " input
    START_DATE=${input:-$START_DATE}
    
    read -p "Date de fin (YYYY-MM) [$END_DATE]: " input
    END_DATE=${input:-$END_DATE}
    
    echo ""
    echo "Modes disponibles:"
    echo "  all        - Pipeline complet (download → load → transform)"
    echo "  download   - Téléchargement uniquement"
    echo "  load       - Chargement uniquement"
    echo "  transform  - Transformation uniquement"
    read -p "Mode [$MODE]: " input
    MODE=${input:-$MODE}
    
    echo ""
    echo -e "${GREEN}[OK]${NC} Configuration mise à jour"
    echo "  - Période: $START_DATE → $END_DATE"
    echo "  - Mode: $MODE"
    echo ""
}

# Lancer le pipeline
run_pipeline() {
    local detach=$1
    local with_tools=$2
    
    # Variables d'environnement
    export START_DATE
    export END_DATE
    export PIPELINE_MODE=$MODE
    export USE_LOCAL=true
    
    # Options compose
    local compose_args="-f $COMPOSE_FILE"
    
    if [ "$with_tools" == "true" ]; then
        compose_args="$compose_args --profile tools"
        echo -e "${CYAN}[INFO]${NC} PgAdmin sera accessible sur ${GREEN}http://localhost:5050${NC}"
        echo "  - Email: admin@local.dev"
        echo "  - Password: admin"
        echo ""
    fi
    
    echo -e "${GREEN}[RUN]${NC} Démarrage du pipeline..."
    echo "  - Période: $START_DATE → $END_DATE"
    echo "  - Mode: $MODE"
    echo ""
    
    if [ "$detach" == "true" ]; then
        docker compose $compose_args up -d --build
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Pipeline lancé en arrière-plan!"
        echo ""
        echo -e "${CYAN}Commandes utiles:${NC}"
        echo "  ./scripts/linux/docker/logs.sh      - Voir les logs"
        echo "  ./scripts/linux/docker/stop.sh      - Arrêter"
        echo ""
    else
        docker compose $compose_args up --build
    fi
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --start-date|-s)
            START_DATE="$2"
            shift 2
            ;;
        --end-date|-e)
            END_DATE="$2"
            shift 2
            ;;
        --mode|-m)
            MODE="$2"
            shift 2
            ;;
        --detach|-d)
            DETACH=true
            shift
            ;;
        --with-tools|-t)
            WITH_TOOLS=true
            shift
            ;;
        --auto|-a)
            # Mode automatique sans menu
            check_docker_running
            check_image
            run_pipeline "false" "false"
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -s, --start-date DATE   Date de début (YYYY-MM), défaut: 2024-01"
            echo "  -e, --end-date DATE     Date de fin (YYYY-MM), défaut: 2024-01"
            echo "  -m, --mode MODE         Mode: download, load, transform, all (défaut)"
            echo "  -d, --detach            Lancer en arrière-plan"
            echo "  -t, --with-tools        Inclure PgAdmin"
            echo "  -a, --auto              Lancer sans menu interactif"
            echo "  -h, --help              Afficher cette aide"
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Option inconnue: $1"
            exit 1
            ;;
    esac
done

# Vérifications
check_docker_running
check_image

# Si des options de lancement sont passées, lancer directement
if [ "$DETACH" == "true" ] || [ "$WITH_TOOLS" == "true" ]; then
    run_pipeline "$DETACH" "$WITH_TOOLS"
    exit 0
fi

# Mode interactif
show_menu
read -p "Votre choix [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        run_pipeline "false" "false"
        ;;
    2)
        run_pipeline "true" "false"
        ;;
    3)
        run_pipeline "false" "true"
        ;;
    4)
        configure_pipeline
        show_menu
        read -p "Votre choix [1]: " choice
        choice=${choice:-1}
        case $choice in
            1) run_pipeline "false" "false" ;;
            2) run_pipeline "true" "false" ;;
            3) run_pipeline "false" "true" ;;
            *) echo -e "${YELLOW}[INFO]${NC} Annulé" ;;
        esac
        ;;
    q|Q)
        echo -e "${YELLOW}[INFO]${NC} Annulé"
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Choix invalide"
        exit 1
        ;;
esac
