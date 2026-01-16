# =============================================================================
# Configuration Environnement : RECETTE (REC / STAGING)
# =============================================================================

# -----------------------------------------------------------------------------
# Général
# -----------------------------------------------------------------------------

project_name = "nyctaxi"
environment  = "rec"
location     = "francecentral"

# Utiliser le même Resource Group pour tous les environnements
use_existing_resource_group  = true
existing_resource_group_name = "fabadiRG"

tags = {
  project     = "nyc-taxi-pipeline"
  managed_by  = "terraform"
  environment = "rec"
}

# -----------------------------------------------------------------------------
# Storage Account
# -----------------------------------------------------------------------------

storage_account_tier     = "Standard"
storage_replication_type = "LRS"
storage_containers       = ["raw", "processed"]

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

acr_sku           = "Standard"  # SKU intermédiaire pour rec
acr_admin_enabled = true

# -----------------------------------------------------------------------------
# Cosmos DB for PostgreSQL
# -----------------------------------------------------------------------------

cosmosdb_postgres_coordinator_vcores     = 2       # Plus de puissance
cosmosdb_postgres_coordinator_storage_mb = 65536   # 64 GB
cosmosdb_postgres_node_count             = 0       # Single-node encore

# ⚠️ Autoriser toutes les IPs (rec - sécurisé par mot de passe + SSL)
postgres_allow_all_ips = true

# ⚠️ IMPORTANT: Définir dans les variables d'environnement ou fichier séparé
# postgres_admin_password = "CHANGE_ME"

# -----------------------------------------------------------------------------
# Log Analytics
# -----------------------------------------------------------------------------

log_analytics_sku            = "PerGB2018"
log_analytics_retention_days = 60  # Plus de rétention pour debug

# -----------------------------------------------------------------------------
# Container Apps
# -----------------------------------------------------------------------------

container_app_cpu          = 1.0    # Plus de CPU
container_app_memory       = "2Gi"
container_app_min_replicas = 0      # Scale to zero possible
container_app_max_replicas = 2

# -----------------------------------------------------------------------------
# Pipeline
# -----------------------------------------------------------------------------

pipeline_start_date = "2024-01"
pipeline_end_date   = "2024-06"  # 6 mois pour tests réalistes
