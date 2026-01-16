# 📐 Structure du Projet - Guide Complet

## 🎯 Vue d'ensemble

Le projet est organisé en **2 modules autonomes** qui remplacent et complètent le brief original :

```
Brief_Terraform_2/
├── terraform_pipeline/     # ⚙️ Infrastructure Azure
└── data_pipeline/          # 🚀 Pipeline de données (autonome)
```

> ✅ **Note**: Le code original a été migré et amélioré dans `data_pipeline/`.

---

## 📦 terraform_pipeline

**Rôle**: Déployer l'infrastructure Azure via Infrastructure as Code.

### Structure

```
terraform_pipeline/
├── terraform/
│   ├── modules/
│   │   └── storage/              # Module réutilisable Storage Account
│   ├── environments/
│   │   ├── dev.tfvars            # Config développement
│   │   ├── rec.tfvars            # Config recette
│   │   ├── prod.tfvars           # Config production
│   │   └── secrets.tfvars        # Secrets (gitignore)
│   ├── main.tf                   # Ressources Azure principales
│   ├── variables.tf               # Variables
│   ├── outputs.tf                 # Outputs
│   └── providers.tf               # Providers Terraform
├── docker/
│   ├── Dockerfile                 # Image Terraform + Azure CLI
│   └── entrypoint.sh              # Script d'entrée
├── scripts/
│   ├── windows/                   # Scripts PowerShell
│   │   ├── docker/               # Gestion Docker
│   │   └── terraform/             # Gestion Terraform
│   └── linux/                     # Scripts Bash
│       ├── docker/
│       └── terraform/
└── docs/                          # Documentation complète
```

### Fonctionnalités

- ✅ Déploiement multi-environnements (dev/rec/prod)
- ✅ Module Storage réutilisable
- ✅ Support Resource Group existant
- ✅ Scripts organisés par plateforme et fonction
- ✅ Documentation complète

---

## 🚀 data_pipeline

**Rôle**: Exécuter les pipelines de données NYC Taxi (projet autonome).

### Structure

```
data_pipeline/
├── pipelines/                     # Code Python des pipelines
│   ├── ingestion/
│   │   └── download.py           # Pipeline 1: Download
│   ├── staging/
│   │   └── load_duckdb.py        # Pipeline 2: Load
│   └── transformation/
│       └── transform.py           # Pipeline 3: Transform
├── utils/                         # Utilitaires Python
│   ├── database.py                # Connexions PostgreSQL/DuckDB
│   ├── download_helper.py         # Téléchargement fichiers
│   └── parquet_utils.py           # Utilitaires Parquet
├── sql/                           # Scripts SQL
│   ├── create_staging_table.sql
│   ├── insert_to.sql
│   └── transformations.sql
├── docker/
│   ├── Dockerfile                 # Image multi-stage avec uv
│   ├── entrypoint.sh              # Script d'entrée
│   └── docker-compose.yml         # Orchestration locale
├── scripts/
│   ├── windows/docker/            # Scripts PowerShell
│   └── linux/docker/              # Scripts Bash
├── docs/                          # Documentation
├── main.py                        # Point d'entrée
├── pyproject.toml                 # Dépendances (uv)
└── uv.lock                        # Lock file
```

### Fonctionnalités

- ✅ **Autonome** : Contient tout le code Python nécessaire
- ✅ **Mode local** : Test avec émulateurs (Azurite, PostgreSQL)
- ✅ **Mode Azure** : Utilise les ressources créées par Terraform
- ✅ **Gestion des dépendances** : Utilise `uv` comme le brief original
- ✅ **Scripts organisés** : Windows/Linux séparés

---

## 🔄 Workflow d'utilisation

### Ordre d'exécution

```
1. terraform_pipeline
   └─► Déployer l'infrastructure Azure
       ├── Storage Account
       ├── Container Registry (ACR)
       ├── Cosmos DB PostgreSQL
       └── Container Apps

2. data_pipeline
   └─► Builder l'image Docker
       └─► Push vers ACR

3. terraform_pipeline
   └─► Finaliser le déploiement
       └─► Container App démarre automatiquement

4. (Optionnel) data_pipeline
   └─► Exécuter manuellement le pipeline
```

Voir [WORKFLOW.md](./WORKFLOW.md) pour les détails.

---

## 🔧 Modules Terraform

### Module Storage

**Emplacement**: `terraform_pipeline/terraform/modules/storage/`

**Usage**:
```hcl
module "storage" {
  source = "./modules/storage"
  
  resource_group_name      = local.resource_group_name
  location                 = local.resource_group_location
  storage_account_name     = "st${var.project_name}${random_string.suffix.result}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  containers               = ["raw", "processed"]
  
  tags = var.tags
}
```

### Modules non nécessaires

| Module | Nécessaire ? | Raison |
|--------|--------------|--------|
| **VM** | ❌ Non | Le Brief utilise Container Apps |
| **WebApp** | ❌ Non | Le Brief utilise Container Apps |

**Conclusion**: Seul le module Storage est nécessaire. Les autres ressources sont spécifiques au projet.

---

## 📊 Utiliser un Resource Group existant

Si tu as déjà un Resource Group Azure :

```hcl
# Dans environments/dev.tfvars
use_existing_resource_group = true
existing_resource_group_name = "mon-rg-existant"
```

Terraform utilisera ce Resource Group au lieu d'en créer un nouveau.

---

## 🆚 Fonctionnalités de data_pipeline

| Aspect | data_pipeline |
|--------|--------------|
| **Code Python** | ✅ Complet et autonome |
| **Dockerfile** | ✅ Multi-stage avec uv |
| **Dépendances** | ✅ pyproject.toml + uv.lock |
| **Scripts** | ✅ Windows/Linux organisés |
| **Documentation** | ✅ Complète dans docs/ |
| **Mode local** | ✅ Avec émulateurs (Azurite, PostgreSQL) |
| **Mode Azure** | ✅ Avec ressources Terraform |

**Résultat**: `data_pipeline` est un projet autonome prêt pour le déploiement.

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [WORKFLOW.md](./WORKFLOW.md) | Guide d'utilisation complet |
| [terraform_pipeline/docs/](./terraform_pipeline/docs/) | Documentation Terraform |
| [data_pipeline/docs/](./data_pipeline/docs/) | Documentation Data Pipeline |

---

## ✅ Avantages de cette structure

1. **Séparation claire** : Infrastructure vs Pipeline de données
2. **Autonomie** : Chaque projet peut fonctionner indépendamment
3. **Réutilisabilité** : Module Storage réutilisable
4. **Organisation** : Scripts organisés par plateforme et fonction
5. **Documentation** : Documentation complète pour chaque module

---

## 🚀 Prochaines étapes

1. Lire [WORKFLOW.md](./WORKFLOW.md) pour comprendre l'ordre d'utilisation
2. Suivre le [Getting Started Terraform](./terraform_pipeline/docs/getting-started.md)
3. Tester en local avec [data_pipeline](./data_pipeline/docs/local-mode.md)
