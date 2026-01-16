#!/bin/bash
# =============================================================================
# Entrypoint Script - Terraform + Azure CLI Container
# =============================================================================
# Ce script initialise l'environnement et verifie la connexion Azure
# =============================================================================

# Note: on n'utilise PAS "set -e" car certaines commandes peuvent echouer
# (ex: az provider register si pas les permissions) sans bloquer le script

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banniere d'accueil
echo -e "${BLUE}"
echo "======================================================================"
echo "           Terraform + Azure CLI Workspace                           "
echo "           NYC Taxi Pipeline Infrastructure                          "
echo "======================================================================"
echo -e "${NC}"

# Creation des repertoires necessaires
mkdir -p /workspace/logs
mkdir -p /workspace/.azure

# Affichage des versions
echo -e "${GREEN}[INFO]${NC} Versions installees:"
echo "  - Terraform: $(terraform version -json | jq -r '.terraform_version')"
echo "  - Azure CLI: $(az version -o tsv --query '"azure-cli"')"
echo ""

# Verification de la connexion Azure
check_azure_login() {
    if az account show &> /dev/null; then
        ACCOUNT_NAME=$(az account show --query "name" -o tsv)
        SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
        echo -e "${GREEN}[OK]${NC} Connecte a Azure"
        echo "  - Subscription: $ACCOUNT_NAME"
        echo "  - ID: $SUBSCRIPTION_ID"
        return 0
    else
        return 1
    fi
}

# Fonction de login via device code
azure_login() {
    echo -e "${YELLOW}[ACTION]${NC} Connexion Azure requise"
    echo ""
    echo -e "${BLUE}Utilisez la methode device-code pour vous connecter:${NC}"
    echo ""
    
    if az login --use-device-code; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Connexion reussie!"
        check_azure_login
        # Enregistrer les providers Azure apres connexion
        register_azure_providers
    else
        echo -e "${RED}[ERROR]${NC} Echec de la connexion Azure"
        echo -e "${YELLOW}[INFO]${NC} Vous pouvez reessayer avec: az login --use-device-code"
        # Ne pas exit, continuer pour permettre l'utilisation du shell
    fi
}

# Fonction pour enregistrer les providers Azure necessaires
register_azure_providers() {
    echo ""
    echo -e "${BLUE}[PROVIDERS]${NC} Verification des providers Azure..."
    
    # Liste des providers necessaires pour ce projet
    PROVIDERS=("Microsoft.App" "Microsoft.ContainerRegistry" "Microsoft.Storage" "Microsoft.OperationalInsights" "Microsoft.DBforPostgreSQL")
    
    # Array pour tracker les providers en attente
    declare -a PENDING_PROVIDERS=()
    
    # Premiere passe : verifier et lancer l'enregistrement si necessaire
    for provider in "${PROVIDERS[@]}"; do
        STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
        
        if [ "$STATE" = "Registered" ]; then
            echo -e "  ${GREEN}[OK]${NC} $provider"
        elif [ "$STATE" = "Registering" ]; then
            echo -e "  ${YELLOW}[...]${NC} $provider (en cours...)"
            PENDING_PROVIDERS+=("$provider")
        else
            echo -e "  ${YELLOW}[->]${NC} $provider (enregistrement...)"
            # || true pour ne pas bloquer si pas les permissions
            az provider register --namespace "$provider" &>/dev/null || true
            PENDING_PROVIDERS+=("$provider")
        fi
    done
    
    # Si des providers sont en attente, attendre qu'ils soient tous prets
    if [ ${#PENDING_PROVIDERS[@]} -gt 0 ]; then
        echo ""
        echo -e "${BLUE}[INFO]${NC} ${#PENDING_PROVIDERS[@]} provider(s) en cours d'enregistrement..."
        echo -e "${BLUE}[INFO]${NC} Attente automatique (max 3 min)..."
        echo ""
        
        # Attendre jusqu'a 3 minutes (36 x 5s)
        MAX_ATTEMPTS=36
        ATTEMPT=0
        
        while [ ${#PENDING_PROVIDERS[@]} -gt 0 ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            ATTEMPT=$((ATTEMPT + 1))
            ELAPSED=$((ATTEMPT * 5))
            
            # Verifier chaque provider en attente
            STILL_PENDING=()
            for provider in "${PENDING_PROVIDERS[@]}"; do
                STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
                if [ "$STATE" = "Registered" ]; then
                    echo -e "  ${GREEN}[OK]${NC} $provider ${GREEN}(pret apres ${ELAPSED}s)${NC}"
                else
                    STILL_PENDING+=("$provider")
                fi
            done
            
            PENDING_PROVIDERS=("${STILL_PENDING[@]}")
            
            # Si tous sont prets, sortir
            if [ ${#PENDING_PROVIDERS[@]} -eq 0 ]; then
                break
            fi
            
            # Afficher progression
            echo -ne "\r  ${YELLOW}[...]${NC} Attente: ${ELAPSED}s / 180s - En attente: ${PENDING_PROVIDERS[*]}   "
            sleep 5
        done
        
        echo ""
        
        # Verification finale
        if [ ${#PENDING_PROVIDERS[@]} -gt 0 ]; then
            echo -e "${YELLOW}[WARNING]${NC} Providers encore en attente apres 3 min:"
            for provider in "${PENDING_PROVIDERS[@]}"; do
                STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
                echo -e "  ${YELLOW}[...]${NC} $provider ($STATE)"
            done
            echo ""
            echo -e "${YELLOW}[INFO]${NC} L'enregistrement continue en arriere-plan."
            echo -e "${YELLOW}[INFO]${NC} Attendez 1-2 min avant terraform apply, ou reessayez si erreur."
        else
            echo -e "${GREEN}[OK]${NC} Tous les providers sont enregistres!"
        fi
    else
        echo -e "${GREEN}[OK]${NC} Tous les providers sont deja enregistres!"
    fi
}

# Fonction pour initialiser Terraform
init_terraform() {
    if [ -f "main.tf" ]; then
        if [ ! -d ".terraform" ]; then
            echo ""
            echo -e "${BLUE}[TERRAFORM]${NC} Initialisation de Terraform..."
            if terraform init; then
                echo -e "${GREEN}[OK]${NC} Terraform initialise!"
            else
                echo -e "${YELLOW}[WARNING]${NC} Terraform init a rencontre des erreurs"
                echo -e "${YELLOW}[INFO]${NC} Vous pouvez reessayer manuellement: terraform init"
            fi
        else
            echo -e "${GREEN}[OK]${NC} Terraform deja initialise"
        fi
    fi
}

# Verification initiale de la connexion
if ! check_azure_login; then
    echo -e "${YELLOW}[INFO]${NC} Vous n'etes pas connecte a Azure"
    echo ""
    read -p "Voulez-vous vous connecter maintenant? (o/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        azure_login
    else
        echo -e "${YELLOW}[WARNING]${NC} Certaines commandes Terraform necessitent une connexion Azure"
    fi
else
    # Si deja connecte, verifier les providers
    register_azure_providers
fi

# Initialiser Terraform automatiquement si necessaire
init_terraform

# =============================================================================
# Creation des commandes simplifiees (disponibles dans le shell)
# =============================================================================

# Creer le fichier de fonctions bash ET l'ajouter au .bashrc
cat > /root/.terraform-helpers.sh << 'HELPERS_EOF'
#!/bin/bash
# Commandes simplifiees pour Terraform

# Couleurs
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_BLUE='\033[0;34m'
_NC='\033[0m'

# Fonction plan
plan() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: plan [dev|rec|prod]"
        return 1
    fi
    echo -e "${_BLUE}[PLAN]${_NC} Environnement: ${_GREEN}$env${_NC}"
    terraform plan -var-file="environments/${env}.tfvars" -var-file="environments/secrets.tfvars"
}

# Fonction apply (avec generation .env automatique)
apply() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: apply [dev|rec|prod]"
        return 1
    fi
    echo -e "${_GREEN}[APPLY]${_NC} Environnement: ${_GREEN}$env${_NC}"
    
    if terraform apply -var-file="environments/${env}.tfvars" -var-file="environments/secrets.tfvars"; then
        echo ""
        echo -e "${_BLUE}[GENERATE]${_NC} Generation du fichier .env..."
        if [ -f "./scripts/generate-env.sh" ]; then
            ./scripts/generate-env.sh "$env"
        else
            echo -e "${_YELLOW}[WARNING]${_NC} Script generate-env.sh non trouve"
        fi
    fi
}

# Fonction destroy (avec suppression .env automatique)
destroy() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: destroy [dev|rec|prod]"
        return 1
    fi
    echo -e "${_RED}[DESTROY]${_NC} Environnement: ${_YELLOW}$env${_NC}"
    
    if terraform destroy -var-file="environments/${env}.tfvars" -var-file="environments/secrets.tfvars"; then
        # Supprimer le fichier .env correspondant
        local env_file="/workspace/shared/.env.${env}"
        if [ -f "$env_file" ]; then
            echo -e "${_YELLOW}[CLEANUP]${_NC} Suppression de $env_file..."
            rm -f "$env_file"
            echo -e "${_GREEN}[OK]${_NC} Fichier .env supprime"
        fi
    fi
}

# Fonction output
output() {
    terraform output "$@"
}

# Fonction pour regenerer le .env sans redeployer
genenv() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: genenv [dev|rec|prod]"
        return 1
    fi
    if [ -f "./scripts/generate-env.sh" ]; then
        ./scripts/generate-env.sh "$env"
    else
        echo -e "${_RED}[ERROR]${_NC} Script generate-env.sh non trouve"
    fi
}

# Fonction Container App - affiche les commandes de gestion
ca() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: ca [dev|rec|prod]"
        return 1
    fi
    
    # Recuperer les noms depuis Terraform (si disponibles)
    local app_name=$(terraform output -raw container_app_name 2>/dev/null || echo "ca-nyctaxi-pipeline-${env}")
    local rg_name=$(terraform output -raw resource_group_name 2>/dev/null || echo "fabadiRG")
    
    echo ""
    echo -e "${_BLUE}======================================================================${_NC}"
    echo -e "${_BLUE}         CONTAINER APP - Commandes de gestion (${env})               ${_NC}"
    echo -e "${_BLUE}======================================================================${_NC}"
    echo ""
    echo -e "${_GREEN}Informations:${_NC}"
    echo "  Container App:    $app_name"
    echo "  Resource Group:   $rg_name"
    echo ""
    echo -e "${_YELLOW}Commandes utiles:${_NC}"
    echo ""
    echo -e "${_BLUE}# Voir le statut${_NC}"
    echo "az containerapp show --name $app_name --resource-group $rg_name --query '{state:properties.runningStatus}'"
    echo ""
    echo -e "${_BLUE}# Lister les revisions${_NC}"
    echo "az containerapp revision list --name $app_name --resource-group $rg_name -o table"
    echo ""
    echo -e "${_BLUE}# Redemarrer la revision active${_NC}"
    echo "az containerapp revision restart --name $app_name --resource-group $rg_name --revision \$(az containerapp revision list --name $app_name --resource-group $rg_name --query '[0].name' -o tsv)"
    echo ""
    echo -e "${_BLUE}# Voir les logs${_NC}"
    echo "az containerapp logs show --name $app_name --resource-group $rg_name --follow"
    echo ""
    echo -e "${_BLUE}# Mettre a l'echelle (0 = arrete, 1+ = actif)${_NC}"
    echo "az containerapp update --name $app_name --resource-group $rg_name --min-replicas 0 --max-replicas 0"
    echo "az containerapp update --name $app_name --resource-group $rg_name --min-replicas 1 --max-replicas 1"
    echo ""
    echo -e "${_BLUE}======================================================================${_NC}"
}

# Fonction help
tfhelp() {
    echo ""
    echo -e "${_BLUE}======================================================================${_NC}"
    echo -e "${_BLUE}                    COMMANDES DISPONIBLES                            ${_NC}"
    echo -e "${_BLUE}======================================================================${_NC}"
    echo ""
    echo -e "${_GREEN}Commandes simplifiees:${_NC}"
    echo "  plan [env]     - Previsualiser (defaut: dev)"
    echo "  apply [env]    - Deployer + generer .env (defaut: dev)"
    echo "  destroy [env]  - Detruire + supprimer .env (defaut: dev)"
    echo "  output         - Voir les outputs Terraform"
    echo "  genenv [env]   - Regenerer le .env sans redeployer"
    echo "  ca [env]       - Commandes Container App"
    echo "  tfhelp         - Afficher cette aide"
    echo ""
    echo -e "${_YELLOW}Environnements:${_NC} dev, rec, prod"
    echo ""
    echo -e "${_BLUE}Exemples:${_NC}"
    echo "  plan dev       - Previsualiser l'environnement dev"
    echo "  apply dev      - Deployer dev + generer shared/.env.dev"
    echo "  destroy prod   - Detruire prod + supprimer shared/.env.prod"
    echo "  ca dev         - Voir les commandes Container App pour dev"
    echo ""
    echo -e "${_BLUE}Autres commandes:${_NC}"
    echo "  az login --use-device-code  - Se reconnecter a Azure"
    echo "  terraform [cmd]             - Commandes Terraform directes"
    echo -e "  ${_RED}exit${_NC}                        - Quitter le workspace"
    echo ""
    echo -e "${_BLUE}======================================================================${_NC}"
}
HELPERS_EOF

# Ajouter au .bashrc pour que les fonctions soient disponibles dans le shell interactif
if ! grep -q "terraform-helpers" /root/.bashrc 2>/dev/null; then
    echo "" >> /root/.bashrc
    echo "# Terraform helper functions" >> /root/.bashrc
    echo "source /root/.terraform-helpers.sh" >> /root/.bashrc
fi

# Sourcer les fonctions pour la session actuelle
source /root/.terraform-helpers.sh

echo ""
echo -e "${GREEN}[READY]${NC} Workspace Terraform pret!"
echo ""

# Afficher l'aide automatiquement
tfhelp

# Execution de la commande passee en argument
exec "$@"
