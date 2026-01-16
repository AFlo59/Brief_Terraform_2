#!/bin/bash
# =============================================================================
# Stop/Remove Script - Data Pipeline Docker Services
# =============================================================================
# Arrête et nettoie les services Docker du pipeline
# Usage: ./stop.sh [--all | --volumes | --prune]
# =============================================================================

set -e

# Configuration
IMAGE_NAME="nyc-taxi-pipeline"
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

# Vérifier si Docker tourne
check_docker_running() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker n'est pas en cours d'exécution!"
        exit 1
    fi
}

# Afficher le statut actuel
show_status() {
    echo -e "${CYAN}[STATUS]${NC} État actuel:"
    
    # Conteneurs du compose
    local containers=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l)
    if [ "$containers" -gt 0 ]; then
        echo -e "  Conteneurs compose: ${GREEN}$containers actif(s)${NC}"
        docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null | tail -n +2 | while read line; do
            echo "    - $line"
        done
    else
        echo -e "  Conteneurs compose: ${YELLOW}Aucun${NC}"
    fi
    
    # Image
    if docker image inspect "${IMAGE_NAME}:latest" &>/dev/null; then
        local size=$(docker image inspect "${IMAGE_NAME}:latest" --format '{{.Size}}' | awk '{printf "%.1f MB", $1/1024/1024}')
        echo -e "  Image pipeline: ${GREEN}${IMAGE_NAME}:latest${NC} ($size)"
    else
        echo -e "  Image pipeline: ${YELLOW}Non trouvée${NC}"
    fi
    
    # Volumes
    local volumes=$(docker volume ls --filter "name=data_pipeline" -q 2>/dev/null | wc -l)
    echo -e "  Volumes pipeline: ${CYAN}$volumes${NC}"
    
    # Volumes dangling
    local dangling=$(docker volume ls -f dangling=true -q 2>/dev/null | wc -l)
    if [ "$dangling" -gt 0 ]; then
        echo -e "  Volumes orphelins: ${YELLOW}$dangling${NC}"
    fi
    
    echo ""
}

# Afficher le menu
show_menu() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Stop/Clean - NYC Taxi Data Pipeline                      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    show_status
    echo -e "${CYAN}Choisissez une option :${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Arrêter les conteneurs (garder les volumes)"
    echo -e "  ${YELLOW}2)${NC} Arrêter + supprimer les volumes"
    echo -e "  ${BLUE}3)${NC} Arrêter + supprimer l'image pipeline"
    echo -e "  ${RED}4)${NC} TOUT supprimer + prune (nettoyage complet)"
    echo ""
    echo -e "  ${CYAN}5)${NC} Supprimer les volumes orphelins uniquement"
    echo ""
    echo -e "  ${RED}q)${NC} Quitter"
    echo ""
}

# Arrêter les conteneurs
stop_containers() {
    echo -e "${YELLOW}[STOP]${NC} Arrêt des conteneurs..."
    docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC} Conteneurs arrêtés"
}

# Arrêter + supprimer volumes
stop_with_volumes() {
    echo -e "${YELLOW}[STOP]${NC} Arrêt des conteneurs + suppression des volumes..."
    docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC} Conteneurs arrêtés et volumes supprimés"
}

# Supprimer l'image
remove_image() {
    echo -e "${YELLOW}[REMOVE]${NC} Suppression de l'image..."
    docker rmi "${IMAGE_NAME}:latest" 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC} Image supprimée"
}

# Nettoyage complet
full_cleanup() {
    echo -e "${RED}[CLEANUP]${NC} Nettoyage complet..."
    
    # Arrêter tout
    docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    
    # Supprimer l'image
    docker rmi "${IMAGE_NAME}:latest" 2>/dev/null || true
    
    # Supprimer les images liées (postgres, azurite, etc.)
    echo -e "${YELLOW}[PRUNE]${NC} Suppression des images inutilisées..."
    docker image prune -f
    
    # Supprimer les volumes orphelins
    echo -e "${YELLOW}[PRUNE]${NC} Suppression des volumes orphelins..."
    docker volume prune -f
    
    echo -e "${GREEN}[OK]${NC} Nettoyage complet terminé"
}

# Supprimer volumes orphelins
remove_dangling_volumes() {
    local count=$(docker volume ls -f dangling=true -q | wc -l)
    if [ "$count" -gt 0 ]; then
        echo -e "${YELLOW}[PRUNE]${NC} Suppression de $count volume(s) orphelin(s)..."
        docker volume prune -f
        echo -e "${GREEN}[OK]${NC} Volumes orphelins supprimés"
    else
        echo -e "${GREEN}[OK]${NC} Aucun volume orphelin"
    fi
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Vérifier Docker
check_docker_running

# Traitement des arguments CLI
case "$1" in
    --stop|-s)
        stop_containers
        exit 0
        ;;
    --volumes|-v)
        stop_with_volumes
        exit 0
        ;;
    --all|-a)
        stop_with_volumes
        remove_image
        exit 0
        ;;
    --prune|-p)
        full_cleanup
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [--stop | --volumes | --all | --prune]"
        echo ""
        echo "Options:"
        echo "  --stop, -s      Arrêter les conteneurs"
        echo "  --volumes, -v   Arrêter + supprimer les volumes"
        echo "  --all, -a       Arrêter + supprimer volumes + image"
        echo "  --prune, -p     Nettoyage complet (tout + prune)"
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
        stop_containers
        ;;
    2)
        stop_with_volumes
        ;;
    3)
        stop_with_volumes
        remove_image
        ;;
    4)
        echo ""
        echo -e "${RED}⚠️  ATTENTION: Cette action supprime TOUTES les données!${NC}"
        read -p "Confirmer? (tapez 'yes'): " confirm
        if [ "$confirm" == "yes" ]; then
            full_cleanup
        else
            echo -e "${YELLOW}[INFO]${NC} Annulé"
        fi
        ;;
    5)
        remove_dangling_volumes
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

echo ""
echo -e "${GREEN}[DONE]${NC} Opération terminée"
