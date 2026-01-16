#!/bin/bash
# =============================================================================
# Terraform Destroy Wrapper - Detruit + supprime .env
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
ENV_FILE="/workspace/shared/.env.${ENV}"

echo -e "${RED}"
echo "======================================================================"
echo "         Terraform Destroy - Environment: ${ENV}                     "
echo "======================================================================"
echo -e "${NC}"

# Verifier que les fichiers tfvars existent
if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouve: $TFVARS_FILE"
    exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier non trouve: $SECRETS_FILE"
    exit 1
fi

# Avertissement
echo -e "${RED}!!! ATTENTION !!!${NC}"
echo ""
echo "Cette action va SUPPRIMER toutes les ressources Azure de l'environnement ${ENV}:"
echo "  - Storage Account et ses donnees"
echo "  - Container Registry et ses images"
echo "  - Base de donnees PostgreSQL et ses donnees"
echo "  - Container App"
echo "  - Log Analytics"
echo ""
echo -e "${YELLOW}Cette action est IRREVERSIBLE !${NC}"
echo ""

# Demander confirmation
read -p "Etes-vous sur de vouloir continuer? (tapez 'yes' pour confirmer): " confirm

if [ "$confirm" != "yes" ]; then
    echo ""
    echo -e "${YELLOW}[CANCEL]${NC} Operation annulee"
    exit 0
fi

echo ""
echo -e "${RED}[DESTROY]${NC} Execution de terraform destroy..."
echo ""

if terraform destroy -var-file="$TFVARS_FILE" -var-file="$SECRETS_FILE"; then
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Terraform destroy termine avec succes!"
    
    # Supprimer le fichier .env
    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}[CLEANUP]${NC} Suppression de ${ENV_FILE}..."
        rm -f "$ENV_FILE"
        echo -e "${GREEN}[OK]${NC} Fichier .env supprime"
    fi
    
    echo ""
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}                    DESTRUCTION TERMINEE                             ${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo ""
    echo "Toutes les ressources Azure de l'environnement ${ENV} ont ete supprimees."
    echo ""
else
    echo ""
    echo -e "${RED}[ERROR]${NC} Terraform destroy a echoue!"
    echo -e "${YELLOW}[INFO]${NC} Certaines ressources peuvent encore exister"
    echo -e "${YELLOW}[INFO]${NC} Verifiez dans le portail Azure"
    exit 1
fi
