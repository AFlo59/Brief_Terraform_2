# =============================================================================
# Terraform Outputs
# =============================================================================
# Valeurs exportées après le déploiement pour référence et debugging
# =============================================================================

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Nom du Resource Group utilisé"
  value       = local.resource_group_name
}

output "resource_group_location" {
  description = "Région du Resource Group"
  value       = local.resource_group_location
}

# -----------------------------------------------------------------------------
# Storage Account
# -----------------------------------------------------------------------------

output "storage_account_name" {
  description = "Nom du Storage Account"
  value       = module.storage.storage_account_name
}

output "storage_account_primary_blob_endpoint" {
  description = "Endpoint principal pour Blob Storage"
  value       = module.storage.primary_blob_endpoint
}

output "storage_containers" {
  description = "Liste des containers créés"
  value       = values(module.storage.containers)
}

# Connexion string marquée comme sensible
output "storage_connection_string" {
  description = "Connection string du Storage Account (sensible)"
  value       = module.storage.primary_connection_string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

output "acr_name" {
  description = "Nom du Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "URL du serveur de login ACR"
  value       = azurerm_container_registry.main.login_server
}

output "acr_admin_username" {
  description = "Username admin du ACR"
  value       = azurerm_container_registry.main.admin_username
}

# Password admin du ACR (sensible)
output "acr_admin_password" {
  description = "Password admin du ACR (sensible)"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

# Commande pour se connecter à ACR
output "acr_login_command" {
  description = "Commande pour se connecter à ACR"
  value       = "az acr login --name ${azurerm_container_registry.main.name}"
}

# Commandes pour builder et pusher l'image
output "docker_build_commands" {
  description = "Commandes Docker pour builder et pusher l'image"
  value       = <<-EOT
    # 1. Se connecter à ACR
    az acr login --name ${azurerm_container_registry.main.name}
    
    # 2. Builder l'image (depuis le dossier data_pipeline)
    cd ../data_pipeline && ./scripts/linux/docker/build.sh
    
    # 3. Tagger l'image
    docker tag nyc-taxi-pipeline:latest ${azurerm_container_registry.main.login_server}/nyc-taxi-pipeline:latest
    
    # 4. Pousser vers ACR
    docker push ${azurerm_container_registry.main.login_server}/nyc-taxi-pipeline:latest
  EOT
}

# -----------------------------------------------------------------------------
# Cosmos DB for PostgreSQL
# -----------------------------------------------------------------------------

output "postgres_host" {
  description = "Hostname du serveur PostgreSQL"
  value       = azurerm_cosmosdb_postgresql_cluster.main.servers[0].fqdn
}

output "postgres_password" {
  description = "Mot de passe PostgreSQL (sensible)"
  value       = var.postgres_admin_password != "" ? var.postgres_admin_password : random_password.postgres.result
  sensitive   = true
}

output "postgres_connection_string" {
  description = "Connection string PostgreSQL (remplacer le mot de passe)"
  value       = "postgresql://citus:<PASSWORD>@${azurerm_cosmosdb_postgresql_cluster.main.servers[0].fqdn}:5432/citus?sslmode=require"
}

# Commande psql pour se connecter
output "psql_connection_command" {
  description = "Commande psql pour se connecter (remplacer <PASSWORD>)"
  value       = "psql \"postgresql://citus:<PASSWORD>@${azurerm_cosmosdb_postgresql_cluster.main.servers[0].fqdn}:5432/citus?sslmode=require\""
}

# -----------------------------------------------------------------------------
# Log Analytics
# -----------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "ID du Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Nom du Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

# -----------------------------------------------------------------------------
# Container Apps
# -----------------------------------------------------------------------------

output "container_app_name" {
  description = "Nom du Container App"
  value       = azurerm_container_app.pipeline.name
}

output "container_app_environment_name" {
  description = "Nom de l'environnement Container Apps"
  value       = azurerm_container_app_environment.main.name
}

# Commandes utiles pour les logs
output "container_app_logs_command" {
  description = "Commande pour voir les logs du Container App"
  value       = "az containerapp logs show --name ${azurerm_container_app.pipeline.name} --resource-group ${local.resource_group_name} --follow"
}

output "container_app_revisions_command" {
  description = "Commande pour lister les révisions du Container App"
  value       = "az containerapp revision list --name ${azurerm_container_app.pipeline.name} --resource-group ${local.resource_group_name}"
}

# -----------------------------------------------------------------------------
# Environment Info (pour génération .env)
# -----------------------------------------------------------------------------

output "environment" {
  description = "Environnement déployé (dev/rec/prod)"
  value       = var.environment
}

# -----------------------------------------------------------------------------
# Résumé de l'infrastructure
# -----------------------------------------------------------------------------

output "infrastructure_summary" {
  description = "Résumé de l'infrastructure déployée"
  value       = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════╗
    ║           NYC Taxi Pipeline - Infrastructure Déployée            ║
    ╚══════════════════════════════════════════════════════════════════╝
    
    📦 Resource Group:     ${local.resource_group_name}
    📍 Région:             ${local.resource_group_location}
    
    💾 Storage Account:    ${module.storage.storage_account_name}
       Containers:         raw, processed
    
    🐳 Container Registry: ${azurerm_container_registry.main.login_server}
    
    🐘 PostgreSQL:         ${azurerm_cosmosdb_postgresql_cluster.main.servers[0].fqdn}
       Database:           citus
       User:               citus
    
    📊 Log Analytics:      ${azurerm_log_analytics_workspace.main.name}
    
    🚀 Container App:      ${azurerm_container_app.pipeline.name}
    
    ─────────────────────────────────────────────────────────────────────
  EOT
}
