# =============================================================================
# Outputs - Module Storage
# =============================================================================

output "storage_account_name" {
  description = "Nom du Storage Account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "ID du Storage Account"
  value       = azurerm_storage_account.main.id
}

output "primary_blob_endpoint" {
  description = "Endpoint principal pour Blob Storage"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_connection_string" {
  description = "Connection string principale (sensible)"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

output "containers" {
  description = "Map des containers créés"
  value       = { for k, v in azurerm_storage_container.containers : k => v.name }
}
