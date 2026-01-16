#!/bin/bash
# =============================================================================
# Entrypoint Script - NYC Taxi Data Pipeline
# =============================================================================

set -e

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           NYC Taxi Data Pipeline                                 ║"
echo "║           Download → Load → Transform                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Afficher la configuration
echo -e "${GREEN}[CONFIG]${NC} Configuration du pipeline:"
echo "  - Mode:        ${PIPELINE_MODE:-all}"
echo "  - Start Date:  ${START_DATE:-non défini}"
echo "  - End Date:    ${END_DATE:-non défini}"
echo "  - Storage:     ${AZURE_CONTAINER_NAME:-raw}"
echo ""

# Vérification des variables requises
check_env() {
    local var_name=$1
    local var_value="${!var_name}"
    if [ -z "$var_value" ]; then
        echo -e "${RED}[ERROR]${NC} Variable $var_name non définie"
        return 1
    fi
    echo -e "${GREEN}[OK]${NC} $var_name configuré"
    return 0
}

echo -e "${YELLOW}[CHECK]${NC} Vérification des variables d'environnement..."

# Variables obligatoires pour Azure
if [ "${USE_LOCAL:-false}" != "true" ]; then
    check_env "AZURE_STORAGE_CONNECTION_STRING" || exit 1
    check_env "POSTGRES_HOST" || exit 1
    check_env "POSTGRES_PASSWORD" || exit 1
fi

check_env "START_DATE" || exit 1
check_env "END_DATE" || exit 1

echo ""
echo -e "${GREEN}[START]${NC} Démarrage du pipeline..."
echo "─────────────────────────────────────────────────────────────────────"
echo ""

# Exécution de la commande
exec "$@"
