#!/bin/bash
# =============================================================================
# Build Script - Data Pipeline Docker Image
# =============================================================================
# Construit l'image Docker pour le pipeline de donnees
# Detecte les environnements Azure et propose le deploiement ACR
# Usage: ./build.sh [--no-cache | --pull | --auto | --deploy ENV]
# =============================================================================

set -e

# Configuration
IMAGE_NAME="nyc-taxi-pipeline"
IMAGE_TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
DOCKER_DIR="$PROJECT_ROOT/docker"
SHARED_DIR="$(dirname "$PROJECT_ROOT")/shared"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables pour les environnements detectes
declare -a AVAILABLE_ENVS=()
declare -A ENV_ACR_SERVERS=()
declare -A ENV_ACR_USERS=()

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

# Verifier si Docker daemon tourne
check_docker_running() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker n'est pas en cours d'execution!"
        echo -e "${YELLOW}[INFO]${NC} Lancez Docker Desktop et reessayez."
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} Docker est en cours d'execution"
}

# Verifier la connexion Docker Hub
check_docker_login() {
    if docker pull --quiet hello-world &>/dev/null 2>&1; then
        docker rmi hello-world &>/dev/null 2>&1 || true
        return 0
    else
        return 1
    fi
}

# Login Docker Hub
do_docker_login() {
    echo -e "${YELLOW}[AUTH]${NC} Connexion a Docker Hub requise..."
    echo -e "${CYAN}[INFO]${NC} Creez un compte gratuit sur https://hub.docker.com si necessaire"
    echo ""
    docker login
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Echec de la connexion a Docker Hub"
        return 1
    fi
    echo -e "${GREEN}[OK]${NC} Connecte a Docker Hub"
    return 0
}

# Verifier/reparer les credentials Docker
ensure_docker_credentials() {
    echo -e "${CYAN}[CHECK]${NC} Verification de la connexion Docker..."
    
    if ! check_docker_login; then
        echo -e "${YELLOW}[WARNING]${NC} Impossible de se connecter a Docker Hub"
        echo ""
        
        read -p "Voulez-vous vous connecter a Docker Hub? (o/n) [o]: " login_choice
        login_choice=${login_choice:-o}
        
        if [[ "$login_choice" =~ ^[oOyY]$ ]]; then
            if [ -f ~/.docker/config.json ]; then
                echo -e "${YELLOW}[INFO]${NC} Reinitialisation de la configuration Docker..."
                rm -f ~/.docker/config.json
            fi
            do_docker_login || exit 1
        else
            echo -e "${YELLOW}[WARNING]${NC} Certaines images pourraient ne pas etre telechargeables"
        fi
    else
        echo -e "${GREEN}[OK]${NC} Connexion Docker fonctionnelle"
    fi
    echo ""
}

# Detecter les environnements Azure disponibles
detect_azure_environments() {
    AVAILABLE_ENVS=()
    
    for env in dev rec prod; do
        local env_file="$SHARED_DIR/.env.$env"
        if [ -f "$env_file" ]; then
            AVAILABLE_ENVS+=("$env")
            
            # Extraire les infos ACR
            local acr_server=$(grep "^ACR_LOGIN_SERVER=" "$env_file" 2>/dev/null | cut -d'=' -f2)
            local acr_user=$(grep "^ACR_USERNAME=" "$env_file" 2>/dev/null | cut -d'=' -f2)
            
            if [ -n "$acr_server" ]; then
                ENV_ACR_SERVERS[$env]="$acr_server"
                ENV_ACR_USERS[$env]="$acr_user"
            fi
        fi
    done
}

# Afficher le statut actuel
show_status() {
    echo -e "${CYAN}[STATUS]${NC} Etat actuel:"
    
    # Image existante ?
    if docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null; then
        local size=$(docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Size}}' | awk '{printf "%.1f MB", $1/1024/1024}')
        local created=$(docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Created}}' | cut -d'T' -f1)
        echo -e "  Image locale: ${GREEN}${IMAGE_NAME}:${IMAGE_TAG}${NC} ($size, $created)"
    else
        echo -e "  Image locale: ${YELLOW}Non trouvee${NC}"
    fi
    
    # Conteneurs en cours ?
    local running=$(docker ps --filter "ancestor=${IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Names}}' 2>/dev/null | wc -l)
    if [ "$running" -gt 0 ]; then
        echo -e "  Conteneurs actifs: ${GREEN}$running${NC}"
    fi
    
    # Environnements Azure
    echo ""
    echo -e "${CYAN}[AZURE]${NC} Environnements detectes:"
    if [ ${#AVAILABLE_ENVS[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}Aucun${NC} - Deployez d'abord avec terraform_pipeline"
    else
        for env in "${AVAILABLE_ENVS[@]}"; do
            local acr="${ENV_ACR_SERVERS[$env]:-N/A}"
            echo -e "  ${GREEN}[OK]${NC} $env -> $acr"
        done
    fi
    echo ""
}

# Afficher le menu
show_menu() {
    echo ""
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}         Build - NYC Taxi Data Pipeline                              ${NC}"
    echo -e "${BLUE}======================================================================${NC}"
    echo ""
    show_status
    echo -e "${CYAN}Choisissez une option :${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Build avec cache (rapide)"
    echo -e "  ${YELLOW}2)${NC} Build sans cache (reconstruction complete)"
    echo -e "  ${BLUE}3)${NC} Mettre a jour les images de base + build"
    
    # Options de deploiement si environnements detectes
    if [ ${#AVAILABLE_ENVS[@]} -gt 0 ]; then
        echo ""
        echo -e "${CYAN}--- Deploiement Azure ---${NC}"
        local opt_num=4
        for env in "${AVAILABLE_ENVS[@]}"; do
            local acr="${ENV_ACR_SERVERS[$env]}"
            echo -e "  ${BLUE}$opt_num)${NC} Build + Deploy vers ${GREEN}$env${NC} ($acr)"
            opt_num=$((opt_num + 1))
        done
    fi
    
    echo ""
    echo -e "  ${RED}q)${NC} Quitter"
    echo ""
}

# Pull les images de base
pull_base_images() {
    echo -e "${CYAN}[PULL]${NC} Telechargement des images de base..."
    
    echo -e "${CYAN}[1/2]${NC} python:3.11-slim-bookworm..."
    docker pull python:3.11-slim-bookworm
    
    echo -e "${CYAN}[2/2]${NC} ghcr.io/astral-sh/uv:python3.11-bookworm-slim..."
    docker pull ghcr.io/astral-sh/uv:python3.11-bookworm-slim
    
    echo -e "${GREEN}[OK]${NC} Images de base telechargees"
    echo ""
}

# S'assurer que les images de base sont disponibles
ensure_base_images() {
    echo -e "${CYAN}[CHECK]${NC} Verification des images de base..."
    
    if ! docker image inspect "ghcr.io/astral-sh/uv:python3.11-bookworm-slim" &>/dev/null; then
        echo -e "${YELLOW}[PULL]${NC} Telechargement de l'image uv..."
        docker pull ghcr.io/astral-sh/uv:python3.11-bookworm-slim || {
            echo -e "${RED}[ERROR]${NC} Impossible de telecharger l'image uv"
            echo -e "${YELLOW}[INFO]${NC} Essayez: docker login ghcr.io"
            exit 1
        }
    fi
    
    if ! docker image inspect "python:3.11-slim-bookworm" &>/dev/null; then
        echo -e "${YELLOW}[PULL]${NC} Telechargement de l'image Python..."
        docker pull python:3.11-slim-bookworm || {
            echo -e "${RED}[ERROR]${NC} Impossible de telecharger l'image Python"
            exit 1
        }
    fi
    
    echo -e "${GREEN}[OK]${NC} Images de base pretes"
    echo ""
}

# Construire l'image
build_image() {
    local no_cache=$1
    local build_opts=""
    
    if [ "$no_cache" == "true" ]; then
        build_opts="--no-cache"
        echo -e "${YELLOW}[INFO]${NC} Mode sans cache active"
    fi
    
    if [ ! -f "$DOCKER_DIR/Dockerfile" ]; then
        echo -e "${RED}[ERROR]${NC} Dockerfile non trouve: $DOCKER_DIR/Dockerfile"
        exit 1
    fi
    
    ensure_base_images
    
    echo -e "${GREEN}[BUILD]${NC} Construction de l'image: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo -e "${GREEN}[INFO]${NC} Contexte de build: $PROJECT_ROOT"
    echo ""
    
    docker build $build_opts \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        -f "$DOCKER_DIR/Dockerfile" \
        "$PROJECT_ROOT"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Image construite avec succes!"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Echec de la construction de l'image"
        exit 1
    fi
}

# Pull + Build
pull_and_build() {
    pull_base_images
    build_image "false"
}

# Deployer vers ACR
deploy_to_acr() {
    local env=$1
    local env_file="$SHARED_DIR/.env.$env"
    
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}[ERROR]${NC} Fichier .env.$env non trouve!"
        exit 1
    fi
    
    # Charger les variables
    local acr_server=$(grep "^ACR_LOGIN_SERVER=" "$env_file" | cut -d'=' -f2)
    local acr_user=$(grep "^ACR_USERNAME=" "$env_file" | cut -d'=' -f2)
    local acr_pass=$(grep "^ACR_PASSWORD=" "$env_file" | cut -d'=' -f2)
    
    if [ -z "$acr_server" ]; then
        echo -e "${RED}[ERROR]${NC} ACR_LOGIN_SERVER non trouve dans .env.$env"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}         Deploiement vers Azure Container Registry                   ${NC}"
    echo -e "${BLUE}======================================================================${NC}"
    echo ""
    echo -e "${CYAN}[INFO]${NC} Environnement: ${GREEN}$env${NC}"
    echo -e "${CYAN}[INFO]${NC} ACR: ${GREEN}$acr_server${NC}"
    echo ""
    
    # Login ACR
    echo -e "${CYAN}[ACR]${NC} Connexion a Azure Container Registry..."
    if [ -n "$acr_pass" ]; then
        echo "$acr_pass" | docker login "$acr_server" -u "$acr_user" --password-stdin
    else
        # Fallback sur az acr login
        echo -e "${YELLOW}[INFO]${NC} Utilisation de az acr login..."
        local acr_name=$(echo "$acr_server" | cut -d'.' -f1)
        az acr login --name "$acr_name"
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Echec de la connexion ACR"
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} Connecte a ACR"
    echo ""
    
    # Tag l'image
    local remote_tag="${acr_server}/${IMAGE_NAME}:${IMAGE_TAG}"
    echo -e "${CYAN}[TAG]${NC} Tag de l'image: $remote_tag"
    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "$remote_tag"
    
    # Push
    echo -e "${CYAN}[PUSH]${NC} Envoi vers ACR..."
    docker push "$remote_tag"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}======================================================================${NC}"
        echo -e "${GREEN}         DEPLOIEMENT TERMINE                                         ${NC}"
        echo -e "${GREEN}======================================================================${NC}"
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Image deployee: $remote_tag"
        echo ""
        echo -e "${CYAN}[INFO]${NC} Le Container App va automatiquement detecter la nouvelle image."
        echo -e "${CYAN}[INFO]${NC} Verifiez dans le portail Azure: Container Apps > $env"
        echo ""
    else
        echo -e "${RED}[ERROR]${NC} Echec du push vers ACR"
        exit 1
    fi
}

# Build + Deploy
build_and_deploy() {
    local env=$1
    local no_cache=${2:-false}
    
    echo -e "${CYAN}[MODE]${NC} Build + Deploy vers ${GREEN}$env${NC}"
    echo ""
    
    # Build
    build_image "$no_cache"
    
    # Deploy
    deploy_to_acr "$env"
}

# Afficher les prochaines etapes
show_next_steps() {
    echo ""
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}                      PROCHAINES ETAPES                               ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    echo ""
    echo -e "${GREEN}Mode local (avec emulateurs):${NC}"
    echo "  ./scripts/linux/docker/run-local.sh"
    echo ""
    echo -e "${BLUE}Mode Azure (avec ressources cloud):${NC}"
    echo "  ./scripts/linux/docker/run-azure.sh"
    echo ""
    
    if [ ${#AVAILABLE_ENVS[@]} -gt 0 ]; then
        echo -e "${YELLOW}Deployer vers Azure:${NC}"
        for env in "${AVAILABLE_ENVS[@]}"; do
            echo "  ./scripts/linux/docker/build.sh --deploy $env"
        done
        echo ""
    fi
    
    echo -e "${RED}Arreter les services:${NC}"
    echo "  ./scripts/linux/docker/stop.sh"
    echo ""
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# 1. Verifier que Docker tourne
check_docker_running

# 2. Verifier les credentials Docker
ensure_docker_credentials

# 3. Detecter les environnements Azure
detect_azure_environments

# 4. Traitement des arguments CLI
case "$1" in
    --no-cache)
        build_image "true"
        show_next_steps
        exit 0
        ;;
    --pull)
        pull_and_build
        show_next_steps
        exit 0
        ;;
    --auto|--cache)
        build_image "false"
        show_next_steps
        exit 0
        ;;
    --deploy)
        if [ -z "$2" ]; then
            echo -e "${RED}[ERROR]${NC} Environnement requis!"
            echo "Usage: $0 --deploy [dev|rec|prod]"
            exit 1
        fi
        build_and_deploy "$2" "false"
        exit 0
        ;;
    --deploy-no-cache)
        if [ -z "$2" ]; then
            echo -e "${RED}[ERROR]${NC} Environnement requis!"
            echo "Usage: $0 --deploy-no-cache [dev|rec|prod]"
            exit 1
        fi
        build_and_deploy "$2" "true"
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --auto, --cache       Build avec cache (par defaut)"
        echo "  --no-cache            Build sans cache (reconstruction complete)"
        echo "  --pull                Pull images de base + build"
        echo "  --deploy ENV          Build + push vers ACR (dev|rec|prod)"
        echo "  --deploy-no-cache ENV Build sans cache + push vers ACR"
        echo "  (aucun)               Affiche le menu interactif"
        exit 0
        ;;
esac

# 5. Mode interactif
show_menu
read -p "Votre choix [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        build_image "false"
        show_next_steps
        ;;
    2)
        build_image "true"
        show_next_steps
        ;;
    3)
        pull_and_build
        show_next_steps
        ;;
    4)
        if [ ${#AVAILABLE_ENVS[@]} -ge 1 ]; then
            build_and_deploy "${AVAILABLE_ENVS[0]}" "false"
        else
            echo -e "${RED}[ERROR]${NC} Choix invalide"
            exit 1
        fi
        ;;
    5)
        if [ ${#AVAILABLE_ENVS[@]} -ge 2 ]; then
            build_and_deploy "${AVAILABLE_ENVS[1]}" "false"
        else
            echo -e "${RED}[ERROR]${NC} Choix invalide"
            exit 1
        fi
        ;;
    6)
        if [ ${#AVAILABLE_ENVS[@]} -ge 3 ]; then
            build_and_deploy "${AVAILABLE_ENVS[2]}" "false"
        else
            echo -e "${RED}[ERROR]${NC} Choix invalide"
            exit 1
        fi
        ;;
    q|Q)
        echo -e "${YELLOW}[INFO]${NC} Annule"
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Choix invalide"
        exit 1
        ;;
esac
