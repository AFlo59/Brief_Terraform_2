# =============================================================================
# Configuration Environnement : PRODUCTION (PROD)
# =============================================================================

# -----------------------------------------------------------------------------
# Général
# -----------------------------------------------------------------------------

project_name = "nyctaxi"
environment  = "prod"
location     = "francecentral"

# Utiliser le même Resource Group pour tous les environnements
use_existing_resource_group  = true
existing_resource_group_name = "fabadiRG"

tags = {
  project     = "nyc-taxi-pipeline"
  managed_by  = "terraform"
  environment = "prod"
}

# -----------------------------------------------------------------------------
# Storage Account
# -----------------------------------------------------------------------------

storage_account_tier     = "Standard"
storage_replication_type = "GRS"   # Geo-redundant pour production
storage_containers       = ["raw", "processed"]

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

acr_sku           = "Premium"  # SKU production avec géo-réplication possible
acr_admin_enabled = true       # À désactiver si on utilise Managed Identity

# -----------------------------------------------------------------------------
# Cosmos DB for PostgreSQL
# -----------------------------------------------------------------------------

cosmosdb_postgres_coordinator_vcores     = 4        # Plus de puissance
cosmosdb_postgres_coordinator_storage_mb = 131072   # 128 GB
cosmosdb_postgres_node_count             = 0        # Augmenter si besoin de distribution

# ⚠️ SÉCURITÉ: Ne JAMAIS autoriser toutes les IPs en production !
postgres_allow_all_ips = false

# ⚠️ IMPORTANT: Utiliser Azure Key Vault en production !
# postgres_admin_password = "CHANGE_ME"

# -----------------------------------------------------------------------------
# Log Analytics
# -----------------------------------------------------------------------------

log_analytics_sku            = "PerGB2018"
log_analytics_retention_days = 90  # Rétention longue pour compliance

# -----------------------------------------------------------------------------
# Container Apps
# -----------------------------------------------------------------------------

container_app_cpu          = 2.0    # Full power
container_app_memory       = "4Gi"
container_app_min_replicas = 1      # Toujours au moins 1 instance (disponibilité)
container_app_max_replicas = 5      # Scaling horizontal

# -----------------------------------------------------------------------------
# Pipeline
# -----------------------------------------------------------------------------

pipeline_start_date = "2023-01"
pipeline_end_date   = "2024-12"  # Année complète de données
