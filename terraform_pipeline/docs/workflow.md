# 🔄 Workflow Complet - Ordre d'Utilisation

Guide complet pour utiliser `terraform_pipeline` et `data_pipeline` dans le bon ordre.

## 📋 Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         WORKFLOW COMPLET                                │
│                                                                         │
│  1. terraform_pipeline  →  Déployer l'infrastructure Azure              │
│  2. data_pipeline       →  Exécuter les pipelines de données            │
│  3. Vérification        →  Consulter les données dans PostgreSQL        │
└─────────────────────────────────────────────────────────────────────────┘
```

## 🎯 Scénario 1: Déploiement complet (recommandé)

### Étape 1: Déployer l'infrastructure avec Terraform

```powershell
# 1.1 Vérifier les prérequis
cd terraform_pipeline
.\scripts\windows\terraform\check-prereqs.ps1

# 1.2 Configurer les secrets
notepad terraform\environments\secrets.tfvars
# Modifier le mot de passe PostgreSQL

# 1.3 Construire et lancer le workspace Terraform
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run.ps1
```

Dans le conteneur Terraform :
```bash
# 1.4 Se connecter à Azure
az login --use-device-code

# 1.5 Initialiser Terraform
terraform init

# 1.6 Prévisualiser
terraform plan -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars

# 1.7 Déployer l'ACR d'abord (pour pouvoir push l'image)
terraform apply \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars \
  -target=azurerm_resource_group.main \
  -target=azurerm_storage_account.main \
  -target=azurerm_container_registry.main

# 1.8 Voir les outputs (noter le nom ACR)
terraform output
```

### Étape 2: Builder et pusher l'image du pipeline

**Sortir du conteneur** (`exit`) puis :

```powershell
# 2.1 Aller dans data_pipeline
cd ..\data_pipeline

# 2.2 Se connecter à ACR (nom affiché dans les outputs)
az acr login --name <acr-name>

# 2.3 Builder l'image
.\scripts\windows\docker\build.ps1

# 2.4 Tagger et pousser vers ACR
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest
docker push <acr-url>/nyc-taxi-pipeline:latest
```

### Étape 3: Finaliser le déploiement Terraform

```powershell
# 3.1 Retourner dans le conteneur Terraform
cd ..\terraform_pipeline
.\scripts\windows\docker\run.ps1
```

Dans le conteneur :
```bash
# 3.2 Déployer le reste (Cosmos DB, Container Apps, etc.)
terraform apply \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars
```

### Étape 4: Exécuter le pipeline de données

**Option A: Via Container Apps (automatique)**

Le Container App démarre automatiquement et exécute le pipeline.

**Option B: Via data_pipeline (manuel)**

```powershell
# 4.1 Aller dans data_pipeline
cd ..\data_pipeline

# 4.2 Construire l'image
.\scripts\windows\docker\build.ps1

# 4.3 Lancer sur Azure
.\scripts\windows\docker\run-azure.ps1 -Env dev -StartDate "2024-01" -EndDate "2024-03"
```

### Étape 5: Vérifier les données

```bash
# 5.1 Voir les logs du Container App
az containerapp logs show \
  --name ca-nyctaxi-pipeline-dev \
  --resource-group rg-nyctaxi-dev \
  --follow

# 5.2 Se connecter à PostgreSQL
psql "postgresql://citus:<PASSWORD>@<HOST>:5432/citus?sslmode=require"

# 5.3 Vérifier les données
SELECT COUNT(*) FROM staging_taxi_trips;
SELECT COUNT(*) FROM fact_trips;
```

---

## 🏠 Scénario 2: Test local (sans Azure)

Pour tester le pipeline sans déployer sur Azure :

```powershell
# 1. Aller dans data_pipeline
cd data_pipeline

# 2. Construire l'image
.\scripts\windows\docker\build.ps1

# 3. Lancer avec émulateurs locaux
.\scripts\windows\docker\run-local.ps1 -StartDate "2024-01" -EndDate "2024-01" -WithTools
```

Cela lance :
- **Azurite** (émulateur Azure Storage)
- **PostgreSQL** local
- **PgAdmin** sur http://localhost:5050

---

## 🔄 Scénario 3: Utiliser un Resource Group existant

Si tu as déjà un Resource Group Azure :

```powershell
# 1. Éditer le fichier d'environnement
notepad terraform\environments\dev.tfvars
```

Ajouter :
```hcl
# Utiliser un Resource Group existant
use_existing_resource_group = true
existing_resource_group_name = "mon-rg-existant"
```

Puis déployer normalement :
```bash
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

---

## 📊 Résumé des commandes par étape

| Étape | Commande | Dossier |
|-------|----------|---------|
| **1. Setup Terraform** | `.\scripts\windows\docker\build.ps1` | `terraform_pipeline/` |
| **2. Déployer infra** | `terraform apply ...` | `terraform_pipeline/` |
| **3. Builder image** | `.\scripts\windows\docker\build.ps1` | `data_pipeline/` |
| **4. Push image** | `docker push ...` | `data_pipeline/` |
| **5. Finaliser infra** | `terraform apply ...` | `terraform_pipeline/` |
| **6. Exécuter pipeline** | `.\scripts\windows\docker\run-azure.ps1` | `data_pipeline/` |

---

## ⚠️ Points d'attention

1. **Ordre obligatoire** :
   - Terraform crée l'ACR → Builder l'image → Push vers ACR → Finaliser Terraform

2. **Image manquante** :
   - Si Container App démarre sans image, il échouera
   - Toujours push l'image avant de finaliser le déploiement

3. **Coûts** :
   - Cosmos DB coûte ~50-70€/mois
   - Faire `terraform destroy` en fin de journée

4. **Secrets** :
   - Ne jamais commiter `secrets.tfvars`
   - Utiliser des mots de passe forts

---

## 🔗 Liens utiles

- [Getting Started Terraform](../docs/getting-started.md)
- [Getting Started Data Pipeline](../../data_pipeline/docs/getting-started.md)
- [Architecture](../docs/architecture.md)
