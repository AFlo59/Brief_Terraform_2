# =============================================================================
# Module: Storage Account + Containers
# =============================================================================
# Module réutilisable pour créer un Storage Account avec des containers
# =============================================================================

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

  # Sécurité
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public  = false
  public_network_access_enabled    = var.public_network_access_enabled

  tags = var.tags
}

# Containers
resource "azurerm_storage_container" "containers" {
  for_each              = toset(var.containers)
  name                  = each.value
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}
