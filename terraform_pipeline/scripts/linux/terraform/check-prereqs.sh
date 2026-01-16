!/bin/bash
# =============================================================================
# Check Prerequisites Script (Bash)
# =============================================================================
# VÃ©rifie que tous les outils nÃ©cessaires sont installÃ©s
# Usage: ./check-prereqs.sh
# =============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

ERROR_COUNT=0

check_result() {
    local name="$1"
    local status="$2"
    local details="$3"
    
    if [ "$status" = "true" ]; then
        echo -e "${GREEN}[OK]${NC}    $name ${GRAY}($details)${NC}"
    else
        echo -e "${RED}[FAIL]${NC}  ${YELLOW}$name${NC}"
        ((ERROR_COUNT++)) || true
    fi
}

check_warn() {
    local name="$1"
    local message="$2"
    echo -e "${YELLOW}[WARN]${NC}  $name - $message"
}

check_info() {
    local message="$1"
    echo -e "${CYAN}[INFO]${NC}  $message"
}

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}    VÃ©rification des prÃ©requis - NYC Taxi Pipeline             ${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------
echo -e "${WHITE}Docker:${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "")
    if [ -n "$DOCKER_VERSION" ]; then
        check_result "Docker Engine" "true" "v$DOCKER_VERSION"
        
        # VÃ©rifier si Docker est en cours d'exÃ©cution
        if docker info &> /dev/null; then
            check_result "Docker Running" "true" "OK"
        else
            check_result "Docker Running" "false" ""
        fi
    else
        check_result "Docker Engine" "false" ""
    fi
else
    check_result "Docker Engine" "false" ""
fi
echo ""

# -----------------------------------------------------------------------------
# Azure CLI
# -----------------------------------------------------------------------------
echo -e "${WHITE}Azure CLI:${NC}"
if command -v az &> /dev/null; then
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "")
    if [ -n "$AZ_VERSION" ]; then
        check_result "Azure CLI" "true" "v$AZ_VERSION"
        
        # VÃ©rifier la connexion Azure
        AZ_ACCOUNT=$(az account show --query "name" -o tsv 2>/dev/null || echo "")
        if [ -n "$AZ_ACCOUNT" ]; then
            check_result "Azure Login" "true" "$AZ_ACCOUNT"
        else
            check_warn "Azure Login" "Non connectÃ© (az login requis)"
        fi
    else
        check_result "Azure CLI" "false" ""
    fi
else
    check_result "Azure CLI" "false" ""
fi
echo ""

# -----------------------------------------------------------------------------
# Fichiers de configuration
# -----------------------------------------------------------------------------
echo -e "${WHITE}Configuration:${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# VÃ©rifier les fichiers d'environnement
[ -f "$TERRAFORM_DIR/environments/dev.tfvars" ] && check_result "environments/dev.tfvars" "true" "OK" || check_result "environments/dev.tfvars" "false" ""
[ -f "$TERRAFORM_DIR/environments/rec.tfvars" ] && check_result "environments/rec.tfvars" "true" "OK" || check_result "environments/rec.tfvars" "false" ""
[ -f "$TERRAFORM_DIR/environments/prod.tfvars" ] && check_result "environments/prod.tfvars" "true" "OK" || check_result "environments/prod.tfvars" "false" ""

# VÃ©rifier secrets.tfvars
SECRETS_FILE="$TERRAFORM_DIR/environments/secrets.tfvars"
if [ -f "$SECRETS_FILE" ]; then
    if grep -q "CHANGEZ_MOI" "$SECRETS_FILE"; then
        check_warn "secrets.tfvars" "Mot de passe par dÃ©faut dÃ©tectÃ©!"
    else
        check_result "environments/secrets.tfvars" "true" "ConfigurÃ©"
    fi
else
    check_warn "secrets.tfvars" "Fichier manquant"
fi
echo ""

# -----------------------------------------------------------------------------
# Fichiers Terraform
# -----------------------------------------------------------------------------
echo -e "${WHITE}Fichiers Terraform:${NC}"
for file in main.tf variables.tf outputs.tf providers.tf; do
    [ -f "$TERRAFORM_DIR/$file" ] && check_result "$file" "true" "OK" || check_result "$file" "false" ""
done
echo ""

# -----------------------------------------------------------------------------
# Docker Image
# -----------------------------------------------------------------------------
echo -e "${WHITE}Image Docker Terraform:${NC}"
if docker image inspect "terraform-azure-workspace:latest" &> /dev/null; then
    check_result "terraform-azure-workspace:latest" "true" "PrÃªte"
else
    check_info "Image non construite - ExÃ©cutez: ./scripts/linux/docker/build.sh"
fi
echo ""

# -----------------------------------------------------------------------------
# RÃ©sumÃ©
# -----------------------------------------------------------------------------
echo -e "${CYAN}================================================================${NC}"
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}Tous les prÃ©requis sont satisfaits!${NC}"
    echo ""
    echo -e "  ${WHITE}Prochaine Ã©tape:${NC}"
    echo "    1. ./scripts/linux/docker/build.sh   (construire l'image)"
    echo "    2. ./scripts/linux/docker/run.sh     (lancer le workspace)"
else
    echo -e "  ${RED}$ERROR_COUNT prÃ©requis manquant(s)${NC}"
    echo ""
    echo -e "  ${WHITE}Actions requises:${NC}"
    echo "    - Installez les outils manquants"
    echo "    - Relancez ce script pour vÃ©rifier"
fi
echo -e "${CYAN}================================================================${NC}"
echo ""
