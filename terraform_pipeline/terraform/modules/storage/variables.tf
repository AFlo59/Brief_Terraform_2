# =============================================================================
# Variables - Module Storage
# =============================================================================

variable "resource_group_name" {
  description = "Nom du Resource Group"
  type        = string
}

variable "location" {
  description = "Région Azure"
  type        = string
}

variable "storage_account_name" {
  description = "Nom du Storage Account (doit être globalement unique)"
  type        = string
}

variable "account_tier" {
  description = "Tier du Storage Account"
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Type de réplication"
  type        = string
  default     = "LRS"
}

variable "containers" {
  description = "Liste des containers à créer"
  type        = list(string)
  default     = []
}

variable "public_network_access_enabled" {
  description = "Autoriser l'accès réseau public"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags à appliquer"
  type        = map(string)
  default     = {}
}
