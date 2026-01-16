#!/bin/bash
# =============================================================================
# Run Script - Terraform Interactive Workspace
# =============================================================================
# Lance un conteneur interactif pour exÃ©cuter des commandes Terraform
# Usage: ./run.sh [--detach] [--cmd "commande"]
# =============================================================================

set -e

# Configuration
IMAGE_NAME="terraform-azure-workspace"
IMAGE_TAG="latest"
CONTAINER_NAME="terraform-workspace"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
MAIN_PROJECT_DIR="$(dirname "$PROJECT_ROOT")"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Arguments
DETACH=false
CUSTOM_CMD=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --detach|-d)
            DETACH=true
            shift
            ;;
        --cmd|-c)
            CUSTOM_CMD="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -d, --detach    Lancer en arriÃ¨re-plan"
            echo "  -c, --cmd       ExÃ©cuter une commande spÃ©cifique"
            echo "  -h, --help      Afficher cette aide"
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Option inconnue: $1"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}[RUN]${NC} DÃ©marrage du workspace Terraform"
echo ""

# VÃ©rifier si l'image existe
if ! docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &> /dev/null; then
    echo -e "${YELLOW}[WARNING]${NC} Image non trouvÃ©e. Construction en cours..."
    "$SCRIPT_DIR/build.sh"
fi

# ArrÃªter et supprimer le conteneur existant si nÃ©cessaire
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}[INFO]${NC} ArrÃªt du conteneur existant..."
    docker rm -f "$CONTAINER_NAME" &> /dev/null || true
fi

# CrÃ©ation des dossiers s'ils n'existent pas
mkdir -p "$TERRAFORM_DIR"
mkdir -p "$MAIN_PROJECT_DIR/shared"

# Chemin du dossier partagÃ©
SHARED_DIR="$MAIN_PROJECT_DIR/shared"

# Options Docker
DOCKER_OPTS="-it"
if [ "$DETACH" = true ]; then
    DOCKER_OPTS="-d"
fi

# Construction de la commande Docker
echo -e "${BLUE}[INFO]${NC} Montage des volumes:"
echo "  - Terraform config: $TERRAFORM_DIR -> /workspace/terraform"
echo "  - Shared (env):     $SHARED_DIR -> /workspace/shared"
echo "  - data_pipeline:    $MAIN_PROJECT_DIR/data_pipeline -> /workspace/data_pipeline (read-only)"
echo ""

# ExÃ©cution du conteneur
if [ -n "$CUSTOM_CMD" ]; then
    echo -e "${GREEN}[EXEC]${NC} Commande: $CUSTOM_CMD"
    docker run --rm $DOCKER_OPTS \
        --name "$CONTAINER_NAME" \
        -v "$TERRAFORM_DIR:/workspace/terraform" \
        -v "$SHARED_DIR:/workspace/shared" \
        -v "$MAIN_PROJECT_DIR/data_pipeline:/workspace/data_pipeline:ro" \
        -w /workspace/terraform \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        bash -c "$CUSTOM_CMD"
else
    echo -e "${GREEN}[EXEC]${NC} Mode interactif"
    docker run --rm $DOCKER_OPTS \
        --name "$CONTAINER_NAME" \
        -v "$TERRAFORM_DIR:/workspace/terraform" \
        -v "$SHARED_DIR:/workspace/shared" \
        -v "$MAIN_PROJECT_DIR/data_pipeline:/workspace/data_pipeline:ro" \
        -w /workspace/terraform \
        "${IMAGE_NAME}:${IMAGE_TAG}"
fi
