#!/bin/bash
# =============================================================================
# Run Azure Script - Data Pipeline sur ressources Azure
# =============================================================================
# Utilise le fichier .env généré par Terraform
# Usage: ./run-azure.sh [--env dev|rec|prod] [options]
# =============================================================================

set -e

# Valeurs par défaut
ENV="dev"
START_DATE=""
END_DATE=""
MODE=""

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
MAIN_PROJECT="$(dirname "$PROJECT_ROOT")"
SHARED_DIR="$MAIN_PROJECT/shared"

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

check_docker_running() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker n'est pas en cours d'exécution!"
        exit 1
    fi
}

check_env_file() {
    local env=$1
    local env_file="$SHARED_DIR/.env.${env}"
    
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}[ERROR]${NC} Fichier .env non trouvé: $env_file"
        echo ""
        echo -e "${YELLOW}[INFO]${NC} Vous devez d'abord déployer l'infrastructure avec Terraform:"
        echo ""
        echo "  1. Lancez le workspace Terraform:"
        echo "     cd ../terraform_pipeline"
        echo "     ./scripts/linux/docker/run.sh"
        echo ""
        echo "  2. Dans le workspace, déployez l'environnement:"
        echo "     apply $env"
        echo ""
        echo "  Le fichier .env.$env sera automatiquement généré."
        return 1
    fi
    return 0
}

show_env_files() {
    echo -e "${CYAN}[STATUS]${NC} Fichiers .env disponibles:"
    
    for env in dev rec prod; do
        local env_file="$SHARED_DIR/.env.${env}"
        if [ -f "$env_file" ]; then
            local date=$(stat -c %y "$env_file" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm "$env_file" 2>/dev/null)
            echo -e "  ${GREEN}✓${NC} .env.${env} (modifié: $date)"
        else
            echo -e "  ${YELLOW}✗${NC} .env.${env} (non trouvé)"
        fi
    done
    echo ""
}

show_menu() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Run Azure - NYC Taxi Data Pipeline                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    show_env_files
    echo -e "${CYAN}Choisissez un environnement :${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} dev  - Développement"
    echo -e "  ${YELLOW}2)${NC} rec  - Recette"
    echo -e "  ${RED}3)${NC} prod - Production"
    echo ""
    echo -e "  ${CYAN}4)${NC} Configurer les options (période, mode)"
    echo ""
    echo -e "  ${RED}q)${NC} Quitter"
    echo ""
}

configure_options() {
    echo ""
    echo -e "${CYAN}[CONFIG]${NC} Configuration du pipeline"
    echo ""
    echo -e "${YELLOW}[INFO]${NC} Laissez vide pour utiliser les valeurs du .env"
    echo ""
    
    read -p "Date de début (YYYY-MM) [depuis .env]: " START_DATE
    read -p "Date de fin (YYYY-MM) [depuis .env]: " END_DATE
    
    echo ""
    echo "Modes disponibles:"
    echo "  all        - Pipeline complet"
    echo "  download   - Téléchargement uniquement"
    echo "  load       - Chargement uniquement"
    echo "  transform  - Transformation uniquement"
    read -p "Mode [depuis .env]: " MODE
    
    echo ""
    echo -e "${GREEN}[OK]${NC} Options configurées"
}

run_pipeline() {
    local env=$1
    local env_file="$SHARED_DIR/.env.${env}"
    
    # Vérifier le fichier .env
    if ! check_env_file "$env"; then
        exit 1
    fi
    
    echo -e "${GREEN}[RUN]${NC} Démarrage du pipeline Azure (${env})..."
    echo ""
    
    # Construire les arguments docker
    local docker_args=("run" "--rm" "-it" "--env-file" "$env_file")
    
    # Overrides optionnels
    if [ -n "$START_DATE" ]; then
        docker_args+=("-e" "START_DATE=$START_DATE")
        echo "  - Start Date: $START_DATE (override)"
    fi
    
    if [ -n "$END_DATE" ]; then
        docker_args+=("-e" "END_DATE=$END_DATE")
        echo "  - End Date: $END_DATE (override)"
    fi
    
    if [ -n "$MODE" ]; then
        docker_args+=("-e" "PIPELINE_MODE=$MODE")
        echo "  - Mode: $MODE (override)"
    fi
    
    # Forcer USE_LOCAL=false pour Azure
    docker_args+=("-e" "USE_LOCAL=false")
    
    docker_args+=("nyc-taxi-pipeline:latest")
    
    echo ""
    
    # Exécuter
    docker "${docker_args[@]}"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Pipeline terminé!"
    else
        echo -e "${RED}[ERROR]${NC} Le pipeline a échoué"
        exit 1
    fi
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env|-e)
            ENV="$2"
            shift 2
            ;;
        --start-date|-s)
            START_DATE="$2"
            shift 2
            ;;
        --end-date)
            END_DATE="$2"
            shift 2
            ;;
        --mode|-m)
            MODE="$2"
            shift 2
            ;;
        --auto|-a)
            check_docker_running
            run_pipeline "$ENV"
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [--env ENV] [options]"
            echo ""
            echo "Options:"
            echo "  -e, --env ENV        Environnement: dev, rec, prod (défaut: dev)"
            echo "  -s, --start-date     Date de début (override .env)"
            echo "  --end-date           Date de fin (override .env)"
            echo "  -m, --mode           Mode: download, load, transform, all"
            echo "  -a, --auto           Lancer sans menu interactif"
            echo "  -h, --help           Afficher cette aide"
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

# Vérifier que l'image existe
if ! docker image inspect "nyc-taxi-pipeline:latest" &>/dev/null; then
    echo -e "${YELLOW}[WARNING]${NC} Image non trouvée. Construction..."
    "$SCRIPT_DIR/build.sh" --auto
fi

# Mode interactif
show_menu
read -p "Votre choix [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        run_pipeline "dev"
        ;;
    2)
        run_pipeline "rec"
        ;;
    3)
        run_pipeline "prod"
        ;;
    4)
        configure_options
        show_menu
        read -p "Votre choix [1]: " choice2
        choice2=${choice2:-1}
        case $choice2 in
            1) run_pipeline "dev" ;;
            2) run_pipeline "rec" ;;
            3) run_pipeline "prod" ;;
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
