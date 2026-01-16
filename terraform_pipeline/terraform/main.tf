# =============================================================================
# Main Terraform Configuration - NYC Taxi Pipeline Infrastructure
# =============================================================================
# Ce fichier définit toutes les ressources Azure pour le projet
# Architecture: Storage -> ACR -> Cosmos DB PostgreSQL -> Container Apps
# =============================================================================

# -----------------------------------------------------------------------------
# Ressources aléatoires pour l'unicité des noms
# -----------------------------------------------------------------------------

# Suffixe aléatoire pour les noms globalement uniques (Storage Account, ACR)
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# Mot de passe PostgreSQL si non fourni
resource "random_password" "postgres" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

# Créer un nouveau Resource Group ou utiliser un existant
resource "azurerm_resource_group" "main" {
  count    = var.use_existing_resource_group ? 0 : 1
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# Data source pour récupérer un Resource Group existant
data "azurerm_resource_group" "existing" {
  count = var.use_existing_resource_group ? 1 : 0
  name  = var.existing_resource_group_name != "" ? var.existing_resource_group_name : "rg-${var.project_name}-${var.environment}"
}

# Variables locales pour le Resource Group à utiliser
locals {
  resource_group_name     = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.main[0].name
  resource_group_location = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].location : azurerm_resource_group.main[0].location
}

# -----------------------------------------------------------------------------
# Storage Account + Blob Containers (via module)
# -----------------------------------------------------------------------------

module "storage" {
  source = "./modules/storage"

  resource_group_name      = local.resource_group_name
  location                 = local.resource_group_location
  # Nom unique par environnement: stnyctaxidev123456
  storage_account_name     = "st${var.project_name}${var.environment}${random_string.suffix.result}"
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type
  containers               = var.storage_containers

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Azure Container Registry (ACR)
# -----------------------------------------------------------------------------

resource "azurerm_container_registry" "main" {
  # Nom unique par environnement: acrnyctaxidev123456
  name                = "acr${var.project_name}${var.environment}${random_string.suffix.result}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  sku                 = var.acr_sku
  admin_enabled       = var.acr_admin_enabled

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Cosmos DB for PostgreSQL (Citus)
# -----------------------------------------------------------------------------

resource "azurerm_cosmosdb_postgresql_cluster" "main" {
  # Nom unique par environnement: c-nyctaxi-dev-123456
  name                            = "c-${var.project_name}-${var.environment}-${random_string.suffix.result}"
  resource_group_name             = local.resource_group_name
  location                        = local.resource_group_location
  administrator_login_password    = var.postgres_admin_password != "" ? var.postgres_admin_password : random_password.postgres.result
  coordinator_storage_quota_in_mb = var.cosmosdb_postgres_coordinator_storage_mb
  coordinator_vcore_count         = var.cosmosdb_postgres_coordinator_vcores
  node_count                      = var.cosmosdb_postgres_node_count

  # SKU Burstable pour 1 vCore (obligatoire selon le BRIEF)
  coordinator_server_edition = "BurstableMemoryOptimized"

  # Configuration haute disponibilité (désactivée pour dev)
  ha_enabled = false

  tags = var.tags
}

# Règle de firewall pour autoriser les services Azure (0.0.0.0)
resource "azurerm_cosmosdb_postgresql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  cluster_id       = azurerm_cosmosdb_postgresql_cluster.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Règle de firewall pour autoriser toutes les IPs (dev/rec uniquement)
# Sécurisé par : mot de passe fort + SSL obligatoire
resource "azurerm_cosmosdb_postgresql_firewall_rule" "allow_all_ips" {
  count            = var.postgres_allow_all_ips ? 1 : 0
  name             = "AllowAllIPs"
  cluster_id       = azurerm_cosmosdb_postgresql_cluster.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# -----------------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}-${var.environment}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Container Apps Environment
# -----------------------------------------------------------------------------

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.project_name}-${var.environment}"
  resource_group_name        = local.resource_group_name
  location                   = local.resource_group_location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Container App - NYC Taxi Pipeline
# -----------------------------------------------------------------------------

resource "azurerm_container_app" "pipeline" {
  name                         = "ca-${var.project_name}-pipeline-${var.environment}"
  resource_group_name          = local.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  # Configuration des secrets
  secret {
    name  = "storage-connection-string"
    value = module.storage.primary_connection_string
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_admin_password != "" ? var.postgres_admin_password : random_password.postgres.result
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  # Configuration du registry privé (ACR)
  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  # Configuration du template de container
  template {
    # Définition du container principal
    container {
      name   = "nyc-taxi-pipeline"
      image  = "${azurerm_container_registry.main.login_server}/nyc-taxi-pipeline:latest"
      cpu    = var.container_app_cpu
      memory = var.container_app_memory

      # Variables d'environnement - Azure Storage
      env {
        name        = "AZURE_STORAGE_CONNECTION_STRING"
        secret_name = "storage-connection-string"
      }

      env {
        name  = "AZURE_CONTAINER_NAME"
        value = "raw"
      }

      # Variables d'environnement - PostgreSQL
      env {
        name  = "POSTGRES_HOST"
        value = azurerm_cosmosdb_postgresql_cluster.main.servers[0].fqdn
      }

      env {
        name  = "POSTGRES_PORT"
        value = "5432"
      }

      env {
        name  = "POSTGRES_DB"
        value = "citus"
      }

      env {
        name  = "POSTGRES_USER"
        value = "citus"
      }

      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }

      env {
        name  = "POSTGRES_SSL_MODE"
        value = "require"
      }

      # Variables d'environnement - Configuration Pipeline
      env {
        name  = "START_DATE"
        value = var.pipeline_start_date
      }

      env {
        name  = "END_DATE"
        value = var.pipeline_end_date
      }
    }

    # Configuration du scaling
    min_replicas = var.container_app_min_replicas
    max_replicas = var.container_app_max_replicas
  }

  tags = var.tags
}
