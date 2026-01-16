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

# Fonction build - Construire et pousser l'image Docker vers l'ACR
# ⚠️ IMPORTANT: A executer AVANT le premier apply !
build() {
    local env=${1:-dev}
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Usage: build [dev|rec|prod]"
        return 1
    fi
    
    echo -e "${_BLUE}======================================================================${_NC}"
    echo -e "${_BLUE}         BUILD & PUSH - Image Docker vers Azure Container Registry   ${_NC}"
    echo -e "${_BLUE}======================================================================${_NC}"
    echo ""
    
    # Recuperer le nom de l'ACR depuis Terraform output ou le construire
    local acr_name=$(terraform output -raw acr_login_server 2>/dev/null | cut -d'.' -f1)
    
    if [[ -z "$acr_name" ]]; then
        # Essayer de le trouver dans Azure directement
        local rg_name=$(grep -E "^existing_resource_group_name" "environments/${env}.tfvars" 2>/dev/null | cut -d'"' -f2)
        if [[ -z "$rg_name" ]]; then
            rg_name=$(grep -E "^resource_group_name" "environments/${env}.tfvars" 2>/dev/null | cut -d'"' -f2)
        fi
        
        if [[ -n "$rg_name" ]]; then
            acr_name=$(az acr list --resource-group "$rg_name" --query "[0].name" -o tsv 2>/dev/null)
        fi
    fi
    
    if [[ -z "$acr_name" ]]; then
        echo -e "${_RED}[ERROR]${_NC} Impossible de trouver le nom de l'ACR"
        echo ""
        echo "Assurez-vous que l'infrastructure de base est deployee (Storage, ACR, etc.)"
        echo "Si c'est le premier deploiement, executez d'abord:"
        echo "  terraform apply -target=azurerm_container_registry.main -var-file=..."
        return 1
    fi
    
    echo -e "${_GREEN}[INFO]${_NC} ACR detecte: ${_YELLOW}$acr_name${_NC}"
    echo -e "${_GREEN}[INFO]${_NC} Source:      /workspace/data_pipeline"
    echo -e "${_GREEN}[INFO]${_NC} Image:       nyc-taxi-pipeline:latest"
    echo ""
    
    # Verifier que le dossier data_pipeline existe
    if [[ ! -d "/workspace/data_pipeline" ]]; then
        echo -e "${_RED}[ERROR]${_NC} Dossier /workspace/data_pipeline non trouve"
        echo "Verifiez que le volume est monte correctement"
        return 1
    fi
    
    # Verifier que le Dockerfile existe
    if [[ ! -f "/workspace/data_pipeline/docker/Dockerfile" ]]; then
        echo -e "${_RED}[ERROR]${_NC} Dockerfile non trouve: /workspace/data_pipeline/docker/Dockerfile"
        return 1
    fi
    
    echo -e "${_YELLOW}[BUILD]${_NC} Construction et push de l'image vers Azure..."
    echo "Cela peut prendre quelques minutes..."
    echo ""
    
    if az acr build --registry "$acr_name" --image nyc-taxi-pipeline:latest /workspace/data_pipeline --file /workspace/data_pipeline/docker/Dockerfile; then
        echo ""
        echo -e "${_GREEN}[SUCCESS]${_NC} Image construite et poussee avec succes !"
        echo ""
        echo -e "${_BLUE}Prochaine etape:${_NC}"
        echo "  apply $env"
    else
        echo ""
        echo -e "${_RED}[ERROR]${_NC} Echec de la construction de l'image"
        return 1
    fi
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

# Fonction import - Importer une ressource existante dans le state Terraform
# Usage simplifie: import <env> <type>  (detecte automatiquement subscription/rg/nom)
# Usage avance:   import <env> <terraform_resource> <azure_resource_id>
import() {
    local env=${1:-}
    local type_or_resource=${2:-}
    local resource_id=${3:-}
    
    # Afficher l'aide si pas assez d'arguments
    if [[ -z "$env" ]] || [[ -z "$type_or_resource" ]]; then
        echo -e "${_BLUE}======================================================================${_NC}"
        echo -e "${_BLUE}         TERRAFORM IMPORT - Importer une ressource existante         ${_NC}"
        echo -e "${_BLUE}======================================================================${_NC}"
        echo ""
        echo -e "${_YELLOW}Usage simplifie (recommande):${_NC}"
        echo "  import <env> <type>"
        echo ""
        echo -e "${_GREEN}Types disponibles:${_NC}"
        echo "  container-app    - Container App pipeline"
        echo "  storage          - Storage Account"
        echo "  registry         - Container Registry"
        echo "  environment      - Container App Environment"
        echo "  postgres         - PostgreSQL Cluster"
        echo ""
        echo -e "${_BLUE}Exemples:${_NC}"
        echo "  import dev container-app   # Importe automatiquement la Container App"
        echo "  import dev storage         # Importe automatiquement le Storage Account"
        echo ""
        echo -e "${_YELLOW}Usage avance:${_NC}"
        echo "  import <env> <terraform_resource> <azure_resource_id>"
        echo ""
        echo -e "${_BLUE}Exemple avance:${_NC}"
        echo "  import dev azurerm_container_app.pipeline \"/subscriptions/.../containerApps/...\""
        echo ""
        echo -e "${_YELLOW}Quand utiliser import ?${_NC}"
        echo "  - Erreur 'resource already exists' lors d'un apply"
        echo "  - Une ressource existe dans Azure mais pas dans le state Terraform"
        echo ""
        echo -e "${_BLUE}======================================================================${_NC}"
        return 1
    fi
    
    # Valider l'environnement
    if [[ ! "$env" =~ ^(dev|rec|prod)$ ]]; then
        echo -e "${_RED}[ERROR]${_NC} Environnement invalide: $env"
        echo "Environnements valides: dev, rec, prod"
        return 1
    fi
    
    # Recuperer automatiquement subscription et resource group
    local subscription_id=$(az account show --query "id" -o tsv 2>/dev/null | tr -d '[:space:]')
    if [[ -z "$subscription_id" ]]; then
        echo -e "${_RED}[ERROR]${_NC} Impossible de recuperer le subscription ID"
        echo "Verifiez que vous etes connecte: az login --use-device-code"
        return 1
    fi
    
    # Recuperer le resource group depuis les tfvars (chercher existing_resource_group_name ou resource_group_name)
    local rg_name=$(grep -E "^existing_resource_group_name" "environments/${env}.tfvars" 2>/dev/null | cut -d'"' -f2)
    if [[ -z "$rg_name" ]]; then
        rg_name=$(grep -E "^resource_group_name" "environments/${env}.tfvars" 2>/dev/null | cut -d'"' -f2)
    fi
    if [[ -z "$rg_name" ]]; then
        echo -e "${_RED}[ERROR]${_NC} Impossible de determiner le resource group depuis environments/${env}.tfvars"
        echo "Verifiez que existing_resource_group_name ou resource_group_name est defini"
        return 1
    fi
    
    # Recuperer le project_name pour construire les noms de ressources
    local project_name=$(grep -E "^project_name" "environments/${env}.tfvars" 2>/dev/null | cut -d'"' -f2)
    if [[ -z "$project_name" ]]; then
        project_name="nyctaxi"
    fi
    
    echo -e "${_BLUE}[INFO]${_NC} Subscription: $subscription_id"
    echo -e "${_BLUE}[INFO]${_NC} Resource Group: $rg_name"
    echo ""
    
    local terraform_resource=""
    local azure_resource_id=""
    
    # Si c'est un type simplifie, construire automatiquement l'ID
    case "$type_or_resource" in
        container-app|containerapp|ca)
            # Chercher le nom exact de la Container App dans Azure
            local ca_name=$(az containerapp list --resource-group "$rg_name" --query "[?contains(name, 'pipeline')].name" -o tsv 2>/dev/null | head -1)
            if [[ -z "$ca_name" ]]; then
                ca_name="ca-${project_name}-pipeline-${env}"
            fi
            terraform_resource="azurerm_container_app.pipeline"
            azure_resource_id="/subscriptions/${subscription_id}/resourceGroups/${rg_name}/providers/Microsoft.App/containerApps/${ca_name}"
            ;;
        storage|storage-account|sa)
            local storage_name=$(az storage account list --resource-group "$rg_name" --query "[0].name" -o tsv 2>/dev/null)
            if [[ -z "$storage_name" ]]; then
                echo -e "${_RED}[ERROR]${_NC} Aucun Storage Account trouve dans $rg_name"
                return 1
            fi
            terraform_resource="module.storage.azurerm_storage_account.main"
            azure_resource_id="/subscriptions/${subscription_id}/resourceGroups/${rg_name}/providers/Microsoft.Storage/storageAccounts/${storage_name}"
            ;;
        registry|acr|container-registry)
            local acr_name=$(az acr list --resource-group "$rg_name" --query "[0].name" -o tsv 2>/dev/null)
            if [[ -z "$acr_name" ]]; then
                echo -e "${_RED}[ERROR]${_NC} Aucun Container Registry trouve dans $rg_name"
                return 1
            fi
            terraform_resource="azurerm_container_registry.main"
            azure_resource_id="/subscriptions/${subscription_id}/resourceGroups/${rg_name}/providers/Microsoft.ContainerRegistry/registries/${acr_name}"
            ;;
        environment|cae|container-environment)
            local cae_name=$(az containerapp env list --resource-group "$rg_name" --query "[0].name" -o tsv 2>/dev/null)
            if [[ -z "$cae_name" ]]; then
                echo -e "${_RED}[ERROR]${_NC} Aucun Container App Environment trouve dans $rg_name"
                return 1
            fi
            terraform_resource="azurerm_container_app_environment.main"
            azure_resource_id="/subscriptions/${subscription_id}/resourceGroups/${rg_name}/providers/Microsoft.App/managedEnvironments/${cae_name}"
            ;;
        postgres|postgresql|db)
            local pg_name=$(az postgres server-arc list --resource-group "$rg_name" --query "[0].name" -o tsv 2>/dev/null || \
                           az cosmosdb postgres cluster list --resource-group "$rg_name" --query "[0].name" -o tsv 2>/dev/null)
            if [[ -z "$pg_name" ]]; then
                echo -e "${_RED}[ERROR]${_NC} Aucun PostgreSQL trouve dans $rg_name"
                echo -e "${_YELLOW}[INFO]${_NC} Pour CosmosDB PostgreSQL, utilisez le mode avance"
                return 1
            fi
            terraform_resource="azurerm_cosmosdb_postgresql_cluster.main"
            azure_resource_id="/subscriptions/${subscription_id}/resourceGroups/${rg_name}/providers/Microsoft.DBforPostgreSQL/serverGroupsv2/${pg_name}"
            ;;
        *)
            # Mode avance: l'utilisateur fournit directement terraform_resource et azure_resource_id
            if [[ -z "$resource_id" ]]; then
                echo -e "${_RED}[ERROR]${_NC} Type inconnu: $type_or_resource"
                echo ""
                echo "Types valides: container-app, storage, registry, environment, postgres"
                echo "Ou utilisez le mode avance: import <env> <terraform_resource> <azure_id>"
                return 1
            fi
            terraform_resource="$type_or_resource"
            azure_resource_id="$resource_id"
            ;;
    esac
    
    echo -e "${_GREEN}[IMPORT]${_NC} Environnement: ${_GREEN}$env${_NC}"
    echo -e "${_GREEN}[IMPORT]${_NC} Ressource TF:  ${_YELLOW}$terraform_resource${_NC}"
    echo -e "${_GREEN}[IMPORT]${_NC} ID Azure:      $azure_resource_id"
    echo ""
    
    terraform import -var-file="environments/${env}.tfvars" -var-file="environments/secrets.tfvars" "$terraform_resource" "$azure_resource_id"
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
    echo "  build [env]    - Construire et push l'image Docker vers ACR"
    echo "  apply [env]    - Deployer + generer .env (defaut: dev)"
    echo "  destroy [env]  - Detruire + supprimer .env (defaut: dev)"
    echo "  import         - Importer une ressource existante (voir: import)"
    echo "  output         - Voir les outputs Terraform"
    echo "  genenv [env]   - Regenerer le .env sans redeployer"
    echo "  ca [env]       - Commandes Container App"
    echo "  tfhelp         - Afficher cette aide"
    echo ""
    echo -e "${_YELLOW}Environnements:${_NC} dev, rec, prod"
    echo ""
    echo -e "${_RED}⚠️  PREMIER DEPLOIEMENT - Ordre des commandes:${_NC}"
    echo "  1. plan dev     - Voir ce qui va etre cree"
    echo "  2. apply dev    - Creer l'infra (Storage, ACR, PostgreSQL...)"
    echo "     -> Si erreur Container App, c'est normal ! Continuez..."
    echo "  3. build dev    - Construire et push l'image vers ACR"
    echo "  4. apply dev    - Finaliser (Container App avec la vraie image)"
    echo ""
    echo -e "${_BLUE}Exemples:${_NC}"
    echo "  plan dev              - Previsualiser l'environnement dev"
    echo "  build dev             - Build et push l'image Docker"
    echo "  apply dev             - Deployer dev + generer shared/.env.dev"
    echo "  destroy prod          - Detruire prod + supprimer shared/.env.prod"
    echo "  import dev container-app  - Importer la Container App (auto-detecte)"
    echo "  ca dev                - Voir les commandes Container App pour dev"
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
