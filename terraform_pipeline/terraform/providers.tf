# =============================================================================
# Terraform Providers Configuration
# =============================================================================
# Configuration des providers requis pour le déploiement Azure
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    # Provider Azure Resource Manager
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }

    # Provider pour générer des valeurs aléatoires (unicité des noms)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Configuration du provider Azure
provider "azurerm" {
  features {
    # Configuration optionnelle des features
    resource_group {
      # Empêche la suppression accidentelle si des ressources existent encore
      prevent_deletion_if_contains_resources = false
    }
  }

  # Utilise automatiquement les credentials de Azure CLI
  # (connecté via `az login --use-device-code` dans le conteneur)
}
