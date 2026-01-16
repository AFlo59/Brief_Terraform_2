# =============================================================================
# Variables Terraform
# =============================================================================
# Définition de toutes les variables utilisées dans le projet
# =============================================================================

# -----------------------------------------------------------------------------
# Variables générales
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Nom du projet (utilisé pour nommer les ressources)"
  type        = string
  default     = "nyctaxi"

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.project_name))
    error_message = "Le nom du projet doit contenir uniquement des lettres minuscules et des chiffres."
  }
}

variable "environment" {
  description = "Environnement de déploiement (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être: dev, staging ou prod."
  }
}

variable "location" {
  description = "Région Azure pour le déploiement"
  type        = string
  default     = "francecentral"
}

variable "use_existing_resource_group" {
  description = "Utiliser un Resource Group existant au lieu d'en créer un nouveau"
  type        = bool
  default     = false
}

variable "existing_resource_group_name" {
  description = "Nom du Resource Group existant (si use_existing_resource_group = true)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags à appliquer à toutes les ressources"
  type        = map(string)
  default = {
    project     = "nyc-taxi-pipeline"
    managed_by  = "terraform"
    environment = "dev"
  }
}

# -----------------------------------------------------------------------------
# Variables Storage Account
# -----------------------------------------------------------------------------

variable "storage_account_tier" {
  description = "Tier du compte de stockage"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Type de réplication du stockage"
  type        = string
  default     = "LRS"
}

variable "storage_containers" {
  description = "Liste des containers à créer dans le Storage Account"
  type        = list(string)
  default     = ["raw", "processed"]
}

# -----------------------------------------------------------------------------
# Variables Container Registry
# -----------------------------------------------------------------------------

variable "acr_sku" {
  description = "SKU du Container Registry Azure"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "Le SKU ACR doit être: Basic, Standard ou Premium."
  }
}

variable "acr_admin_enabled" {
  description = "Activer l'accès admin au Container Registry"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Variables Cosmos DB for PostgreSQL
# -----------------------------------------------------------------------------

variable "cosmosdb_postgres_coordinator_vcores" {
  description = "Nombre de vCores pour le coordinateur"
  type        = number
  default     = 1
}

variable "cosmosdb_postgres_coordinator_storage_mb" {
  description = "Stockage en MB pour le coordinateur"
  type        = number
  default     = 32768 # 32 GB
}

variable "cosmosdb_postgres_node_count" {
  description = "Nombre de nœuds workers (0 pour single-node)"
  type        = number
  default     = 0
}

variable "postgres_admin_username" {
  description = "Nom d'utilisateur admin PostgreSQL"
  type        = string
  default     = "citus"
}

variable "postgres_admin_password" {
  description = "Mot de passe admin PostgreSQL"
  type        = string
  sensitive   = true
  default     = ""  # Sera généré automatiquement si non fourni
}

variable "postgres_allow_all_ips" {
  description = "Autoriser toutes les IPs à se connecter (dev/rec uniquement, pas prod!)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Variables Log Analytics
# -----------------------------------------------------------------------------

variable "log_analytics_sku" {
  description = "SKU du Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Durée de rétention des logs en jours"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# Variables Container Apps
# -----------------------------------------------------------------------------

variable "container_app_cpu" {
  description = "CPU alloué au Container App (en cores)"
  type        = number
  default     = 0.5
}

variable "container_app_memory" {
  description = "Mémoire allouée au Container App"
  type        = string
  default     = "1Gi"
}

variable "container_app_min_replicas" {
  description = "Nombre minimum de réplicas"
  type        = number
  default     = 0
}

variable "container_app_max_replicas" {
  description = "Nombre maximum de réplicas"
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# Variables Pipeline
# -----------------------------------------------------------------------------

variable "pipeline_start_date" {
  description = "Date de début pour le téléchargement des données (format: YYYY-MM)"
  type        = string
  default     = "2024-01"

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}$", var.pipeline_start_date))
    error_message = "La date doit être au format YYYY-MM."
  }
}

variable "pipeline_end_date" {
  description = "Date de fin pour le téléchargement des données (format: YYYY-MM)"
  type        = string
  default     = "2024-03"

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}$", var.pipeline_end_date))
    error_message = "La date doit être au format YYYY-MM."
  }
}
