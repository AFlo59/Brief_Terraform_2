#!/bin/bash
# =============================================================================
# Build Script - Terraform Docker Image
# =============================================================================
# Construit ou rÃ©cupÃ¨re l'image Docker pour le workspace Terraform
# Usage: ./build.sh [--no-cache | --pull | --auto]
# =============================================================================

set -e

# Configuration
IMAGE_NAME="terraform-azure-workspace"
IMAGE_TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
DOCKER_DIR="$PROJECT_ROOT/docker"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fonction pour vÃ©rifier si Docker daemon tourne
check_docker_running() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker n'est pas en cours d'exÃ©cution!"
        echo -e "${YELLOW}[INFO]${NC} Lancez Docker Desktop et rÃ©essayez."
        exit 1
    fi
}

# Fonction pour vÃ©rifier si connectÃ© Ã  Docker Hub
check_docker_login() {
    # VÃ©rifie si on peut pull une image publique (test de connexion)
    if docker pull --quiet hello-world &>/dev/null 2>&1; then
        docker rmi hello-world &>/dev/null 2>&1 || true
        return 0
    else
        return 1
    fi
}

# Fonction pour le docker login
do_docker_login() {
    echo -e "${YELLOW}[AUTH]${NC} Connexion Ã  Docker Hub requise..."
    echo -e "${CYAN}[INFO]${NC} CrÃ©ez un compte gratuit sur https://hub.docker.com si nÃ©cessaire"
    echo ""
    docker login
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Ã‰chec de la connexion Ã  Docker Hub"
        return 1
    fi
    echo -e "${GREEN}[OK]${NC} ConnectÃ© Ã  Docker Hub"
    return 0
}

# Fonction pour vÃ©rifier et rÃ©parer les credentials Docker
ensure_docker_credentials() {
    echo -e "${CYAN}[CHECK]${NC} VÃ©rification de la connexion Docker..."
    
    # Test si Docker peut accÃ©der au registry
    if ! check_docker_login; then
        echo -e "${YELLOW}[WARNING]${NC} Impossible de se connecter Ã  Docker Hub"
        echo ""
        
        # Demander si on veut se connecter
        read -p "Voulez-vous vous connecter Ã  Docker Hub? (o/n) [o]: " login_choice
        login_choice=${login_choice:-o}
        
        if [[ "$login_choice" =~ ^[oOyY]$ ]]; then
            # Supprimer le fichier config corrompu si prÃ©sent
            if [ -f ~/.docker/config.json ]; then
                echo -e "${YELLOW}[INFO]${NC} RÃ©initialisation de la configuration Docker..."
                rm -f ~/.docker/config.json
            fi
            
            do_docker_login || exit 1
        else
            echo -e "${RED}[ERROR]${NC} Connexion Docker requise pour tÃ©lÃ©charger les images de base"
            exit 1
        fi
    else
        echo -e "${GREEN}[OK]${NC} Connexion Docker fonctionnelle"
    fi
    echo ""
}

# Fonction pour afficher le menu
show_menu() {
    echo ""
    echo -e "${BLUE}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${NC}"
    echo -e "${BLUE}â•‘         Build - Terraform Azure Workspace                        â•‘${NC}"
    echo -e "${BLUE}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo ""
    echo -e "${CYAN}Choisissez une option :${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Build avec cache (rapide si dÃ©jÃ  construit)"
    echo -e "  ${YELLOW}2)${NC} Build sans cache (reconstruction complÃ¨te)"
    echo -e "  ${BLUE}3)${NC} Mettre Ã  jour les images de base + build"
    echo ""
    echo -e "  ${RED}q)${NC} Quitter"
    echo ""
}

# Fonction pour s'assurer que l'image de base est disponible
ensure_base_image() {
    echo -e "${CYAN}[PULL]${NC} VÃ©rification de l'image de base Terraform..."
    
    # Toujours pull l'image de base pour Ã©viter les erreurs de credentials BuildKit
    if ! docker pull hashicorp/terraform:1.7.0; then
        echo -e "${RED}[ERROR]${NC} Impossible de tÃ©lÃ©charger l'image de base"
        echo -e "${YELLOW}[INFO]${NC} Essayez: docker login"
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} Image de base prÃªte"
    echo ""
}

# Fonction pour construire l'image
build_image() {
    local no_cache=$1
    local build_opts=""
    
    if [ "$no_cache" == "true" ]; then
        build_opts="--no-cache"
        echo -e "${YELLOW}[INFO]${NC} Mode sans cache activÃ©"
    fi
    
    # VÃ©rification du Dockerfile
    if [ ! -f "$DOCKER_DIR/Dockerfile" ]; then
        echo -e "${RED}[ERROR]${NC} Dockerfile non trouvÃ©: $DOCKER_DIR/Dockerfile"
        exit 1
    fi
    
    # S'assurer que l'image de base est disponible
    ensure_base_image
    
    echo -e "${GREEN}[BUILD]${NC} Construction de l'image: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo -e "${GREEN}[INFO]${NC} Contexte de build: $DOCKER_DIR"
    echo ""
    
    docker build $build_opts \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        -f "$DOCKER_DIR/Dockerfile" \
        "$DOCKER_DIR"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Image construite avec succÃ¨s!"
        show_next_steps
    else
        echo -e "${RED}[ERROR]${NC} Ã‰chec de la construction de l'image"
        exit 1
    fi
}

# Fonction pour pull les images de base et build
pull_and_build() {
    echo -e "${BLUE}[PULL]${NC} TÃ©lÃ©chargement des images de base..."
    
    # Pull l'image de base Terraform
    docker pull hashicorp/terraform:1.7.0
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} Image de base tÃ©lÃ©chargÃ©e"
        echo ""
        echo -e "${CYAN}[INFO]${NC} Construction de l'image locale..."
        build_image "false"
    else
        echo -e "${RED}[ERROR]${NC} Ã‰chec du tÃ©lÃ©chargement"
        exit 1
    fi
}

# Fonction pour afficher les prochaines Ã©tapes
show_next_steps() {
    echo ""
    echo -e "${CYAN}Prochaines Ã©tapes :${NC}"
    echo "  ./scripts/linux/docker/run.sh"
    echo ""
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# 1. VÃ©rifier que Docker tourne
check_docker_running

# 2. VÃ©rifier/rÃ©parer les credentials Docker (AVANT tout build)
ensure_docker_credentials

# 3. Traitement des arguments en ligne de commande
case "$1" in
    --no-cache)
        build_image "true"
        exit 0
        ;;
    --pull)
        pull_and_build
        exit 0
        ;;
    --auto|--cache)
        build_image "false"
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [--no-cache | --pull | --auto]"
        echo ""
        echo "Options:"
        echo "  --auto, --cache  Build avec cache (par dÃ©faut)"
        echo "  --no-cache       Build sans cache (reconstruction complÃ¨te)"
        echo "  --pull           Pull images de base + build"
        echo "  (aucun)          Affiche le menu interactif"
        exit 0
        ;;
esac

# 4. Mode interactif si pas d'arguments
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
        pull_and_build
        ;;
    q|Q)
        echo -e "${YELLOW}[INFO]${NC} AnnulÃ©"
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Choix invalide"
        exit 1
        ;;
esac
