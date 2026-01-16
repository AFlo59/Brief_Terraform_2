# 🗺️ Roadmap - NYC Taxi Pipeline Infrastructure

## 📋 Résumé du Projet

**Objectif** : Déployer une infrastructure Azure pour analyser les données des taxis de New York via Infrastructure as Code (Terraform).

**Durée estimée** : 2-3 jours

---

## ✅ Checklist de Progression

### 🔧 Phase 1 : Setup et Configuration (Jour 1)

- [x] Installer Azure CLI (local + WSL)
- [x] Se connecter à Azure (`az login`)
- [x] Installer Docker Desktop
- [x] Créer la structure Terraform dans Docker
- [x] Créer les fichiers Terraform de base (providers.tf, variables.tf, main.tf, outputs.tf)
- [x] Créer les configurations multi-environnements (dev, rec, prod)
- [x] Créer le fichier `environments/secrets.tfvars` (template)
- [x] Créer le script de vérification des prérequis
- [x] Ajouter la documentation troubleshooting au README
- [x] Réorganiser les scripts par plateforme (windows/linux) et fonction (docker/terraform)
- [x] Créer le module Storage réutilisable
- [x] Ajouter support Resource Group existant
- [x] Code Python intégré dans data_pipeline
- [x] data_pipeline autonome et complet
- [x] ✅ Corriger download.py pour respecter USE_LOCAL
- [x] ✅ Améliorer load_duckdb.py avec meilleurs logs
- [x] ✅ Créer le GUIDE_DEBUTANT.md (guide pas à pas)
- [ ] 🚀 **PROCHAINE ÉTAPE**: Vérifier les prérequis (`.\scripts\windows\terraform\check-prereqs.ps1`)
- [ ] Construire l'image Docker Terraform (`.\scripts\windows\docker\build.ps1`)
- [ ] Lancer le workspace Terraform (`.\scripts\windows\docker\run.ps1`)
- [ ] Se connecter à Azure dans le conteneur (`az login --use-device-code`)
- [ ] Modifier le mot de passe dans `environments/secrets.tfvars`
- [ ] Exécuter `terraform init`
- [ ] Exécuter `.\scripts\deploy.ps1 -Env dev -Action plan` et corriger les erreurs

### 🏗️ Phase 2 : Déploiement Infrastructure (Jour 2)

- [ ] Déployer l'ACR avec Terraform (`terraform apply -target=azurerm_container_registry.main`)
- [ ] Builder l'image NYC Taxi Pipeline (dans `data_pipeline/`)
- [ ] Se connecter à ACR (`az acr login --name <acr-name>`)
- [ ] Tagger et pousser l'image vers ACR
- [ ] Déployer l'infrastructure complète (`terraform apply`)
- [ ] Vérifier les ressources créées dans Azure Portal
- [ ] Consulter les logs du Container App
- [ ] Vérifier les données dans PostgreSQL

### 📝 Phase 3 : Documentation et Finition (Jour 3)

- [ ] Rédiger le README.md final avec instructions complètes
- [ ] Ajouter des captures d'écran du déploiement
- [ ] Documenter les erreurs rencontrées et solutions
- [ ] Tester la reproductibilité (`terraform destroy` + `terraform apply`)
- [ ] Nettoyer le code Terraform (commentaires, organisation)
- [ ] Préparer le repository GitHub
- [ ] (Bonus) Enregistrer une vidéo démo

---

## 📦 Livrables Attendus

| Livrable | Poids | Status |
|----------|-------|--------|
| Code Terraform complet et commenté | 60% | ✅ Créé |
| Scripts de déploiement multi-env | - | ✅ Créé |
| Data Pipeline (local + Azure) | - | ✅ Créé |
| Documentation README.md | 30% | ✅ Créé (à finaliser après déploiement) |
| Section Troubleshooting | - | ✅ Créé |
| Captures d'écran | - | ⏳ À faire après déploiement |
| Démonstration vidéo (bonus) | +10% | ❌ Non commencé |

---

## 🎯 Prochaines Actions Immédiates

### Action 0 : Vérifier les prérequis ✅

```powershell
cd terraform_pipeline
.\scripts\windows\terraform\check-prereqs.ps1
```

### Action 1 : Configurer le mot de passe PostgreSQL

```powershell
# Éditer le fichier secrets.tfvars
notepad terraform\environments\secrets.tfvars
# Remplacer "CHANGEZ_MOI_MotDePasse123!" par un vrai mot de passe
```

### Action 2 : Construire et lancer le workspace Docker

```powershell
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run.ps1
```

### Action 3 : Dans le conteneur - Se connecter à Azure

```bash
# Le script propose automatiquement la connexion
# Sinon manuellement:
az login --use-device-code
# Ouvrir https://microsoft.com/devicelogin et entrer le code
```

### Action 4 : Déployer l'infrastructure

```bash
# Initialiser Terraform
terraform init

# Prévisualiser les changements (environnement DEV)
./scripts/deploy.sh dev plan

# Déployer l'ACR d'abord (pour pouvoir push l'image ensuite)
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars \
  -target=azurerm_resource_group.main \
  -target=azurerm_storage_account.main \
  -target=azurerm_container_registry.main
```

### Action 5 : Builder et pusher l'image NYC Taxi

```powershell
# HORS du conteneur Docker (dans PowerShell Windows)
cd ..\data_pipeline

# Se connecter à ACR (le nom est affiché dans les outputs Terraform)
az acr login --name <acr-name>

# Builder et pousser l'image
.\scripts\windows\docker\build.ps1
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest
docker push <acr-url>/nyc-taxi-pipeline:latest
```

### Action 6 : Finaliser le déploiement

```powershell
# Retourner dans le conteneur Terraform
cd ..\terraform_pipeline
.\scripts\windows\docker\run.ps1

# Déployer le reste de l'infrastructure
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

---

## 🏛️ Architecture à Déployer

```
┌─────────────────────────────────────────────────────────────────┐
│                        AZURE - francecentral                    │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Resource Group: rg-nyctaxi-dev                           │   │
│  │                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │   │
│  │  │  Storage    │  │    ACR      │  │   Log Analytics │   │   │
│  │  │  Account    │  │  (Basic)    │  │    Workspace    │   │   │
│  │  │ raw/proc    │  │             │  │                 │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘   │   │
│  │                                            │             │   │
│  │  ┌─────────────────────────────────────────┴──────────┐  │   │
│  │  │        Container Apps Environment                  │  │   │
│  │  │  ┌──────────────────────────────────────────────┐  │  │   │
│  │  │  │  Container App: ca-nyctaxi-pipeline-dev      │  │  │   │
│  │  │  │  - Pipeline 1: Download → Blob Storage       │  │  │   │
│  │  │  │  - Pipeline 2: Load → PostgreSQL             │  │  │   │
│  │  │  │  - Pipeline 3: Transform (Star Schema)       │  │  │   │
│  │  │  └──────────────────────────────────────────────┘  │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                                                          │   │
│  │  ┌─────────────────────────────────────────────────────┐ │   │
│  │  │  Cosmos DB for PostgreSQL (Citus)                   │ │   │
│  │  │  - 1 vCore (BurstableMemoryOptimized)               │ │   │
│  │  │  - 32 GB Storage                                    │ │   │
│  │  │  - Tables: staging, dim_*, fact_trips               │ │   │
│  │  └─────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚠️ Points d'Attention

1. **Ordre d'exécution** :
   - Terraform crée l'ACR
   - Builder et pousser l'image Docker **AVANT** terraform apply complet
   - Sinon Container App échoue (image manquante)

2. **SKU Cosmos DB** :
   - Utiliser **BurstableMemoryOptimized** pour 1 vCore
   - ❌ Ne PAS utiliser GeneralPurpose avec 1 vCore (erreur)

3. **Firewall PostgreSQL** :
   - La règle 0.0.0.0 autorise les services Azure
   - Ajouter votre IP si vous voulez vous connecter depuis votre machine

4. **Coûts** :
   - Cosmos DB ~ 50-70€/mois si actif 24/7
   - 💡 Faire `terraform destroy` en fin de journée

---

## 📚 Ressources Utiles

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Cosmos DB for PostgreSQL](https://learn.microsoft.com/en-us/azure/cosmos-db/postgresql/)
- [Data Pipeline](./data_pipeline/README.md)

---

*Dernière mise à jour : Phase 1 - Préparation terminée, prêt pour le déploiement Docker*
