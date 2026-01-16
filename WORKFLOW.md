# 🔄 Workflow Complet - Guide d'Utilisation

Guide complet pour utiliser les 3 projets dans le bon ordre.

## 📁 Structure des 3 projets

```
Brief_Terraform_2/
├── terraform_pipeline/     # ⚙️ Infrastructure Azure (Terraform)
│   ├── terraform/          # Config Terraform
│   │   ├── modules/        # Modules réutilisables (storage)
│   │   └── environments/   # Configs dev/rec/prod
│   ├── docker/             # Image Terraform + Azure CLI
│   └── scripts/            # Scripts Windows/Linux
│
└── data_pipeline/          # 🚀 Pipeline de données (autonome)
    ├── pipelines/          # Code Python des pipelines
    ├── utils/              # Utilitaires Python
    ├── sql/                # Scripts SQL
    ├── docker/             # Image Docker du pipeline
    ├── pyproject.toml      # Dépendances (uv)
    └── scripts/            # Scripts Windows/Linux
```

## 🎯 Ordre d'utilisation

### 1️⃣ Déployer l'infrastructure Azure

**Projet**: `terraform_pipeline/`

```powershell
cd terraform_pipeline

# Vérifier les prérequis
.\scripts\windows\terraform\check-prereqs.ps1

# Configurer les secrets
notepad terraform\environments\secrets.tfvars

# Construire et lancer le workspace Terraform
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run.ps1
```

Dans le conteneur :
```bash
az login --use-device-code
terraform init
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars \
  -target=azurerm_resource_group.main \
  -target=azurerm_storage_account.main \
  -target=azurerm_container_registry.main
```

**Résultat** : Infrastructure Azure créée (Storage, ACR, etc.)

---

### 2️⃣ Builder et pusher l'image Docker

**Projet**: `data_pipeline/`

```powershell
# Sortir du conteneur Terraform
exit

cd ..\data_pipeline

# Récupérer le nom ACR (depuis les outputs Terraform ou Azure Portal)
az acr login --name <acr-name>

# Builder l'image (utilise uv avec pyproject.toml)
.\scripts\windows\docker\build.ps1

# Tagger et pousser
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest
docker push <acr-url>/nyc-taxi-pipeline:latest
```

**Résultat** : Image Docker disponible dans ACR

---

### 3️⃣ Finaliser le déploiement Terraform

**Projet**: `terraform_pipeline/`

```powershell
cd ..\terraform_pipeline
.\scripts\windows\docker\run.ps1
```

Dans le conteneur :
```bash
# Déployer le reste (Cosmos DB, Container Apps)
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

**Résultat** : Infrastructure complète, Container App démarre automatiquement

---

### 4️⃣ (Optionnel) Exécuter manuellement le pipeline

**Projet**: `data_pipeline/`

Si tu veux exécuter le pipeline manuellement au lieu d'attendre Container Apps :

```powershell
cd ..\data_pipeline

# Construire l'image
.\scripts\windows\docker\build.ps1

# Lancer sur Azure
.\scripts\windows\docker\run-azure.ps1 -Env dev -StartDate "2024-01" -EndDate "2024-03"
```

**Résultat** : Pipeline exécuté manuellement

---

## 🏠 Alternative: Test local (sans Azure)

Pour tester sans déployer sur Azure :

```powershell
cd data_pipeline
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run-local.ps1 -StartDate "2024-01" -EndDate "2024-01" -WithTools
```

Cela lance :
- **Azurite** (émulateur Azure Storage)
- **PostgreSQL** local
- **PgAdmin** sur http://localhost:5050

---

## 🔧 Utiliser un Resource Group existant

Si tu as déjà un Resource Group Azure :

```powershell
# Éditer le fichier d'environnement
notepad terraform_pipeline\terraform\environments\dev.tfvars
```

Ajouter :
```hcl
use_existing_resource_group = true
existing_resource_group_name = "mon-rg-existant"
```

Puis déployer normalement.

---

## 📊 Résumé visuel

```
┌─────────────────────────────────────────────────────────────────┐
│                    WORKFLOW COMPLET                             │
│                                                                 │
│  1. terraform_pipeline                                          │
│     └─► Déployer Azure (Storage, ACR, PostgreSQL, etc.)         │
│                                                                 │
│  2. data_pipeline                                               │
│     └─► Builder image Docker → Push vers ACR                    │
│                                                                 │
│  3. terraform_pipeline                                          │
│     └─► Finaliser déploiement (Container Apps)                  │
│                                                                 │
│  4. (Optionnel) data_pipeline                                   │
│     └─► Exécuter pipeline manuellement                          │
│                                                                 │
│  5. Vérification                                                │
│     └─► Consulter logs et données PostgreSQL                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚠️ Points importants

### Ordre obligatoire

1. **Terraform crée l'ACR** → Builder l'image → Push vers ACR → Finaliser Terraform
2. Si tu finalises Terraform avant de push l'image, Container App échouera

### Docker séparés

- **terraform_pipeline/docker/** : Image Terraform + Azure CLI (pour gérer l'infra)
- **data_pipeline/docker/** : Image Python (pour exécuter le pipeline)
- Les deux projets sont **indépendants** et autonomes

### Dépendances

- `data_pipeline` est **autonome** avec son propre code Python
- `data_pipeline` peut utiliser les ressources créées par `terraform_pipeline`
- Les 2 projets sont complémentaires mais indépendants

---

## 📚 Documentation détaillée

- [Workflow Terraform Pipeline](../terraform_pipeline/docs/workflow.md)
- [Sync avec le Brief](../terraform_pipeline/docs/sync-brief.md)
- [Getting Started Data Pipeline](../data_pipeline/docs/getting-started.md)

---

## 🆘 Besoin d'aide ?

1. Vérifie les prérequis : `.\scripts\windows\terraform\check-prereqs.ps1`
2. Consulte le [Troubleshooting](../terraform_pipeline/docs/troubleshooting.md)
3. Vérifie la [FAQ](../terraform_pipeline/docs/faq.md)
