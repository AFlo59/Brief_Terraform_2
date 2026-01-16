# ⚙️ Configuration Terraform

## Structure des fichiers

```
terraform/
├── providers.tf      # Configuration des providers
├── variables.tf      # Déclaration des variables
├── main.tf           # Définition des ressources
├── outputs.tf        # Valeurs exportées
└── environments/     # Configurations par environnement
```

## Providers

### Azure Resource Manager (azurerm)

```hcl
provider "azurerm" {
  features {}
}
```

- Version : ~> 3.90
- Authentification via Azure CLI (`az login`)

### Random

```hcl
provider "random" {}
```

- Version : ~> 3.6
- Génère des suffixes uniques pour les noms globaux

## Ressources créées

### Vue d'ensemble

| Ressource | Type Terraform | Nom |
|-----------|---------------|-----|
| Resource Group | `azurerm_resource_group` | rg-{project}-{env} |
| Storage Account | `azurerm_storage_account` | st{project}{random} |
| Storage Containers | `azurerm_storage_container` | raw, processed |
| Container Registry | `azurerm_container_registry` | acr{project}{random} |
| Cosmos DB PostgreSQL | `azurerm_cosmosdb_postgresql_cluster` | cosmos-{project}-{env} |
| Firewall Rule | `azurerm_cosmosdb_postgresql_firewall_rule` | AllowAzureServices |
| Log Analytics | `azurerm_log_analytics_workspace` | log-{project}-{env} |
| Container Apps Env | `azurerm_container_app_environment` | cae-{project}-{env} |
| Container App | `azurerm_container_app` | ca-{project}-pipeline-{env} |

### Dépendances

```
random_string.suffix
       │
       ├──► azurerm_storage_account.main
       │           │
       │           └──► azurerm_storage_container.containers
       │
       └──► azurerm_container_registry.main
                   │
                   └──────────────────────────────┐
                                                  │
azurerm_resource_group.main ◄─────────────────────┤
       │                                          │
       ├──► azurerm_cosmosdb_postgresql_cluster   │
       │           │                              │
       │           └──► firewall_rule             │
       │                                          │
       ├──► azurerm_log_analytics_workspace       │
       │           │                              │
       │           └──► container_app_environment │
       │                       │                  │
       │                       └──► container_app ◄
       │
       └──► storage_account
```

## Variables principales

### Générales

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `project_name` | string | "nyctaxi" | Nom du projet |
| `environment` | string | "dev" | Environnement (dev/rec/prod) |
| `location` | string | "francecentral" | Région Azure |
| `tags` | map(string) | {...} | Tags des ressources |

### Storage

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `storage_account_tier` | string | "Standard" | Tier du compte |
| `storage_replication_type` | string | "LRS" | Type de réplication |
| `storage_containers` | list(string) | ["raw", "processed"] | Containers à créer |

### Container Registry

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `acr_sku` | string | "Basic" | SKU (Basic/Standard/Premium) |
| `acr_admin_enabled` | bool | true | Activer l'admin |

### Cosmos DB PostgreSQL

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `cosmosdb_postgres_coordinator_vcores` | number | 1 | Nombre de vCores |
| `cosmosdb_postgres_coordinator_storage_mb` | number | 32768 | Stockage (MB) |
| `cosmosdb_postgres_node_count` | number | 0 | Nodes workers |
| `postgres_admin_password` | string | "" | Mot de passe admin |

### Container Apps

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `container_app_cpu` | number | 0.5 | CPU (cores) |
| `container_app_memory` | string | "1Gi" | Mémoire |
| `container_app_min_replicas` | number | 0 | Min replicas |
| `container_app_max_replicas` | number | 1 | Max replicas |

### Pipeline

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `pipeline_start_date` | string | "2024-01" | Date début (YYYY-MM) |
| `pipeline_end_date` | string | "2024-03" | Date fin (YYYY-MM) |

## Outputs

### Identifiants

```hcl
output "resource_group_name"    # Nom du Resource Group
output "storage_account_name"   # Nom du Storage Account
output "acr_name"               # Nom du Container Registry
output "acr_login_server"       # URL du serveur ACR
output "postgres_host"          # Hostname PostgreSQL
output "container_app_name"     # Nom du Container App
```

### Commandes utiles

```hcl
output "acr_login_command"            # az acr login ...
output "docker_build_commands"        # Commandes build/push
output "psql_connection_command"      # Commande psql
output "container_app_logs_command"   # az containerapp logs ...
```

### Sensibles

```hcl
output "storage_connection_string"    # Connection string (sensitive)
```

## Commandes Terraform

### Initialisation

```bash
terraform init
```

### Planification

```bash
terraform plan \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars
```

### Application

```bash
terraform apply \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars
```

### Destruction

```bash
terraform destroy \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars
```

### Déploiement ciblé

```bash
# Déployer uniquement certaines ressources
terraform apply \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars \
  -target=azurerm_resource_group.main \
  -target=azurerm_container_registry.main
```

### Voir les outputs

```bash
terraform output

# Output spécifique
terraform output acr_login_server

# Output sensible
terraform output -raw storage_connection_string
```

### Rafraîchir l'état

```bash
terraform refresh \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars
```

## State Terraform

### Emplacement

Par défaut, le state est local :
```
terraform/
└── terraform.tfstate      # État actuel
└── terraform.tfstate.backup  # Backup
```

### Backend distant (optionnel)

Pour un travail en équipe, configurez un backend Azure :

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "nyctaxi.terraform.tfstate"
  }
}
```

## Bonnes pratiques

### Validation

```bash
# Valider la syntaxe
terraform validate

# Formater le code
terraform fmt
```

### Planifier avant d'appliquer

Toujours faire `terraform plan` avant `terraform apply` pour vérifier les changements.

### Utiliser les variables

Ne jamais hardcoder les valeurs sensibles directement dans les fichiers `.tf`.

### Tagger les ressources

Toutes les ressources doivent avoir des tags pour faciliter la gestion et le suivi des coûts.
