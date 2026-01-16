!/bin/bash
# =============================================================================
# Deploy Script - DÃ©ploiement par environnement
# =============================================================================
# Usage: ./deploy.sh <env> <action>
#   env:    dev | rec | prod
#   action: plan | apply | destroy
# =============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Arguments
ENV="${1:-}"
ACTION="${2:-plan}"

# Validation
if [[ -z "$ENV" ]] || [[ ! "$ENV" =~ ^(dev|rec|prod)$ ]]; then
    echo -e "${RED}[ERROR]${NC} Environnement invalide ou manquant"
    echo ""
    echo "Usage: $0 <env> [action]"
    echo ""
    echo "Environnements:"
    echo "  dev   - DÃ©veloppement"
    echo "  rec   - Recette (staging)"
    echo "  prod  - Production"
    echo ""
    echo "Actions:"
    echo "  plan    - PrÃ©visualiser les changements (dÃ©faut)"
    echo "  apply   - Appliquer les changements"
    echo "  destroy - DÃ©truire l'infrastructure"
    exit 1
fi

if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    echo -e "${RED}[ERROR]${NC} Action invalide: $ACTION"
    echo "Actions valides: plan, apply, destroy"
    exit 1
fi

# Chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
ENV_FILE="$TERRAFORM_DIR/environments/${ENV}.tfvars"
SECRETS_FILE="$TERRAFORM_DIR/environments/secrets.tfvars"

# VÃ©rifications
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier d'environnement non trouvÃ©: $ENV_FILE"
    exit 1
fi

# BanniÃ¨re
echo -e "${BLUE}"
echo "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—"
echo "â•‘           Terraform Deployment - NYC Taxi Pipeline               â•‘"
echo "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
echo -e "${NC}"
echo -e "ðŸ“ Environnement: ${GREEN}${ENV}${NC}"
echo -e "ðŸŽ¯ Action:        ${YELLOW}${ACTION}${NC}"
echo ""

# Confirmation pour destroy en prod
if [[ "$ACTION" == "destroy" && "$ENV" == "prod" ]]; then
    echo -e "${RED}âš ï¸  ATTENTION: Vous Ãªtes sur le point de DÃ‰TRUIRE l'environnement PRODUCTION !${NC}"
    read -p "Tapez 'DESTROY PROD' pour confirmer: " CONFIRM
    if [[ "$CONFIRM" != "DESTROY PROD" ]]; then
        echo -e "${YELLOW}[CANCELLED]${NC} OpÃ©ration annulÃ©e"
        exit 0
    fi
fi

# Changement vers le dossier Terraform
cd "$TERRAFORM_DIR"

# Initialisation si nÃ©cessaire
if [ ! -d ".terraform" ]; then
    echo -e "${GREEN}[INIT]${NC} Initialisation de Terraform..."
    terraform init
fi

# Construction des arguments var-file
VAR_FILES="-var-file=environments/${ENV}.tfvars"
if [ -f "$SECRETS_FILE" ]; then
    VAR_FILES="$VAR_FILES -var-file=environments/secrets.tfvars"
else
    echo -e "${YELLOW}[WARNING]${NC} Fichier secrets.tfvars non trouvÃ©"
    echo "CrÃ©ez-le avec: cp environments/secrets.tfvars.example environments/secrets.tfvars"
fi

# ExÃ©cution de l'action
echo ""
echo -e "${GREEN}[EXEC]${NC} terraform $ACTION $VAR_FILES"
echo "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€"

case $ACTION in
    plan)
        terraform plan $VAR_FILES
        ;;
    apply)
        terraform apply $VAR_FILES -auto-approve
        ;;
    destroy)
        terraform destroy $VAR_FILES -auto-approve
        ;;
esac

echo ""
echo -e "${GREEN}[DONE]${NC} OpÃ©ration terminÃ©e!"
