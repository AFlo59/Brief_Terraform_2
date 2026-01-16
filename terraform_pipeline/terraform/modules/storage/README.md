# Module: Storage

Module Terraform pour créer un Storage Account Azure avec des containers.

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  storage_account_name     = "st${var.project_name}${random_string.suffix.result}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  containers               = ["raw", "processed"]
  
  tags = var.tags
}
```

## Variables

| Variable | Type | Description |
|----------|------|-------------|
| `resource_group_name` | string | Nom du Resource Group |
| `location` | string | Région Azure |
| `storage_account_name` | string | Nom du Storage Account |
| `account_tier` | string | Tier (Standard) |
| `account_replication_type` | string | Réplication (LRS/GRS) |
| `containers` | list(string) | Liste des containers |

## Outputs

| Output | Description |
|--------|-------------|
| `storage_account_name` | Nom du Storage Account |
| `primary_blob_endpoint` | Endpoint Blob |
| `primary_connection_string` | Connection string (sensitive) |
| `containers` | Map des containers |
