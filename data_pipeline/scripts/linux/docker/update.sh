#!/bin/bash
# =============================================================================
# Update Script - Data Pipeline Docker Image
# =============================================================================
# Met à jour l'image Docker du pipeline
# Usage: ./update.sh [--quick | --full | --pull]
# =============================================================================

set -e

# Configuration
IMAGE_NAME="nyc-taxi-pipeline"
IMAGE_TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
DOCKER_DIR="$PROJECT_ROOT/docker"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

check_docker_running() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker n'est pas en cours d'exécution!"
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} Docker est en cours d'exécution"
}

show_status() {
    echo -e "${CYAN}[STATUS]${NC} État actuel:"
    
    # Image existante ?
    if docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null; then
        local size=$(docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Size}}' | awk '{printf "%.1f MB", $1/1024/1024}')
        local created=$(docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Created}}' | cut -d'T' -f1)
        echo -e "  Image: ${GREEN}${IMAGE_NAME}:${IMAGE_TAG}${NC} ($size, créée le $created)"
    else
        echo -e "  Image: ${YELLOW}Non trouvée${NC}"
    fi
    
    # Images de base
    echo -e "  ${CYAN}Images de base:${NC}"
    for img in "python:3.11-slim-bookworm" "ghcr.io/astral-sh/uv:python3.11-bookworm-slim"; do
        if docker image inspect "$img" &>/dev/null; then
            echo -e "    ${GREEN}✓${NC} $img"
        else
            echo -e "    ${YELLOW}✗${NC} $img (non téléchargée)"
        fi
    done
    
    # Conteneurs en cours ?
    local running=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l)
    if [ "$running" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} $running conteneur(s) actif(s) - seront redémarrés"
    fi
    echo ""
}

show_menu() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Update - NYC Taxi Data Pipeline                          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    show_status
    echo -e "${CYAN}Choisissez une option :${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Quick update (avec cache)"
    echo -e "  ${YELLOW}2)${NC} Full rebuild (sans cache)"
    echo -e "  ${BLUE}3)${NC} Pull images de base + rebuild"
    echo -e "  ${CYAN}4)${NC} Update + Relancer les services"
    echo ""
    echo -e "  ${RED}q)${NC} Quitter"
    echo ""
}

pull_base_images() {
    echo -e "${CYAN}[PULL]${NC} Téléchargement des images de base..."
    
    echo -e "${CYAN}[1/2]${NC} python:3.11-slim-bookworm..."
    docker pull python:3.11-slim-bookworm
    
    echo -e "${CYAN}[2/2]${NC} ghcr.io/astral-sh/uv:python3.11-bookworm-slim..."
    docker pull ghcr.io/astral-sh/uv:python3.11-bookworm-slim
    
    echo -e "${GREEN}[OK]${NC} Images de base mises à jour"
    echo ""
}

backup_image() {
    if docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null; then
        echo -e "${CYAN}[BACKUP]${NC} Sauvegarde de l'image actuelle..."
        docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:backup" 2>/dev/null || true
    fi
}

restore_image() {
    if docker image inspect "${IMAGE_NAME}:backup" &>/dev/null; then
        echo -e "${YELLOW}[RESTORE]${NC} Restauration de l'image précédente..."
        docker tag "${IMAGE_NAME}:backup" "${IMAGE_NAME}:${IMAGE_TAG}"
        docker rmi "${IMAGE_NAME}:backup" 2>/dev/null || true
    fi
}

cleanup_backup() {
    docker rmi "${IMAGE_NAME}:backup" 2>/dev/null || true
}

build_image() {
    local no_cache=$1
    local build_opts=""
    
    if [ "$no_cache" == "true" ]; then
        build_opts="--no-cache"
        echo -e "${YELLOW}[INFO]${NC} Mode sans cache activé"
    fi
    
    backup_image
    
    echo -e "${GREEN}[BUILD]${NC} Construction de l'image: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    
    if docker build $build_opts \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        -f "$DOCKER_DIR/Dockerfile" \
        "$PROJECT_ROOT"; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Image mise à jour avec succès!"
        cleanup_backup
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Échec de la mise à jour"
        restore_image
        return 1
    fi
}

restart_services() {
    local running=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l)
    if [ "$running" -gt 0 ]; then
        echo -e "${YELLOW}[RESTART]${NC} Redémarrage des services..."
        docker compose -f "$COMPOSE_FILE" up -d --build
        echo -e "${GREEN}[OK]${NC} Services redémarrés"
    fi
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

check_docker_running

# Traitement des arguments CLI
case "$1" in
    --quick|-q)
        build_image "false"
        exit 0
        ;;
    --full|-f)
        build_image "true"
        exit 0
        ;;
    --pull|-p)
        pull_base_images
        build_image "false"
        exit 0
        ;;
    --restart|-r)
        build_image "false"
        restart_services
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [--quick | --full | --pull | --restart]"
        echo ""
        echo "Options:"
        echo "  --quick, -q     Build avec cache (rapide)"
        echo "  --full, -f      Build sans cache (complet)"
        echo "  --pull, -p      Pull images de base + build"
        echo "  --restart, -r   Build + redémarrer les services"
        echo "  (aucun)         Affiche le menu interactif"
        exit 0
        ;;
esac

# Mode interactif
show_menu
read -p "Votre choix [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        build_image "false"
        ;;
    2)
        build_image "true"
        ;;
    3)
        pull_base_images
        build_image "false"
        ;;
    4)
        build_image "false"
        restart_services
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
