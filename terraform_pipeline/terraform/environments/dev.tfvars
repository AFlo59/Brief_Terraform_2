# =============================================================================
# Configuration Environnement : DÉVELOPPEMENT (DEV)
# =============================================================================

# -----------------------------------------------------------------------------
# Général
# -----------------------------------------------------------------------------

project_name = "nyctaxi"
environment  = "dev"
location     = "westeurope"

# Utiliser un Resource Group existant
use_existing_resource_group  = true
existing_resource_group_name = "fabadiRG"

tags = {
  project     = "nyc-taxi-pipeline"
  managed_by  = "terraform"
  environment = "dev"
}

# -----------------------------------------------------------------------------
# Storage Account
# -----------------------------------------------------------------------------

storage_account_tier     = "Standard"
storage_replication_type = "LRS"  # Pas de réplication (moins cher)
storage_containers       = ["raw", "processed"]

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

acr_sku           = "Basic"  # SKU minimum pour dev
acr_admin_enabled = true

# -----------------------------------------------------------------------------
# Cosmos DB for PostgreSQL
# -----------------------------------------------------------------------------

cosmosdb_postgres_coordinator_vcores     = 1      # Minimum
cosmosdb_postgres_coordinator_storage_mb = 32768  # 32 GB
cosmosdb_postgres_node_count             = 0      # Single-node

# ⚠️ Autoriser toutes les IPs (dev uniquement - sécurisé par mot de passe + SSL)
postgres_allow_all_ips = true

# ⚠️ IMPORTANT: Définir dans secrets.tfvars
# postgres_admin_password = "CHANGE_ME"

# -----------------------------------------------------------------------------
# Log Analytics
# -----------------------------------------------------------------------------

log_analytics_sku            = "PerGB2018"
log_analytics_retention_days = 30  # Minimum pour dev

# -----------------------------------------------------------------------------
# Container Apps
# -----------------------------------------------------------------------------

container_app_cpu          = 0.5   # Minimum
container_app_memory       = "1Gi"
container_app_min_replicas = 0     # Scale to zero (économies)
container_app_max_replicas = 1

# -----------------------------------------------------------------------------
# Pipeline
# -----------------------------------------------------------------------------

pipeline_start_date = "2024-01"
pipeline_end_date   = "2024-02"  # 2 mois pour tests
