#!/bin/bash
# =============================================================================
# Terraform Apply Wrapper - Deploie + genere .env
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

cd "$TERRAFORM_DIR" || exit 1

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verifier l'argument
if [ -z "$1" ]; then
    echo -e "${RED}[ERROR]${NC} Environnement requis!"
    echo ""
    echo "Usage: $0 <environment>"
    echo ""
    echo "Environnements disponibles:"
    echo -e "  ${GREEN}dev${NC}   - Developpement"
    echo -e "  ${YELLOW}rec${NC}   - Recette"
    echo -e "  ${RED}prod${NC}  - Production"
    exit 1
fi

ENV="$1"
TFVARS_FILE="environments/${ENV}.tfvars"
SECRETS_FILE="environments/secrets.tfvars"

echo -e "${BLUE}"
echo "======================================================================"
echo "         Terraform Apply - Environment: ${ENV}                       "
echo "======================================================================"
echo -e "${NC}"

# Verifier que les fichiers tfvars existent
if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouve: $TFVARS_FILE"
    exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouve: $SECRETS_FILE"
    echo -e "${YELLOW}[INFO]${NC} Creez-le a partir de secrets.tfvars.example"
    exit 1
fi

# Executer terraform apply
echo -e "${GREEN}[APPLY]${NC} Execution de terraform apply..."
echo ""

if terraform apply -var-file="$TFVARS_FILE" -var-file="$SECRETS_FILE"; then
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Terraform apply termine avec succes!"
    echo ""
    
    # Generer le fichier .env
    echo -e "${BLUE}[GENERATE]${NC} Generation du fichier .env..."
    "$SCRIPT_DIR/generate-env.sh" "$ENV"
    
    echo ""
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}                    DEPLOIEMENT TERMINE                              ${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo ""
    echo -e "Fichier .env genere: ${BLUE}/workspace/shared/.env.${ENV}${NC}"
    echo ""
    echo -e "Prochaines etapes:"
    echo "  1. Le data_pipeline peut maintenant utiliser les ressources Azure"
    echo "  2. Lancez le pipeline avec: docker-compose up"
    echo ""
else
    echo ""
    echo -e "${RED}[ERROR]${NC} Terraform apply a echoue!"
    echo -e "${YELLOW}[INFO]${NC} Verifiez les erreurs ci-dessus"
    exit 1
fi
