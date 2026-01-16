# 🚀 NYC Taxi Pipeline - Infrastructure & Data Pipeline

Projet complet pour déployer une infrastructure Azure et exécuter un pipeline de données pour analyser les données des taxis de New York.

## 📁 Structure du projet

```
Brief_Terraform_2/
├── terraform_pipeline/     # ⚙️ Infrastructure Azure (Terraform)
│   ├── terraform/          # Configuration Terraform
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
    └── scripts/            # Scripts Windows/Linux
```

## 🎯 Vue d'ensemble

### terraform_pipeline
Déploie l'infrastructure Azure complète :
- Storage Account (Blob Storage)
- Container Registry (ACR)
- Cosmos DB for PostgreSQL
- Container Apps Environment
- Log Analytics

### data_pipeline
Exécute les pipelines de données :
- **Pipeline 1**: Download → Télécharge les Parquet depuis NYC TLC
- **Pipeline 2**: Load → Charge dans PostgreSQL via DuckDB
- **Pipeline 3**: Transform → Crée le modèle en étoile (Star Schema)

## 🚀 Démarrage rapide

### 1. Déployer l'infrastructure

```powershell
cd terraform_pipeline
.\scripts\windows\terraform\check-prereqs.ps1
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run.ps1
```

Dans le conteneur :
```bash
az login --use-device-code
terraform init
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

### 2. Builder et pusher l'image

```powershell
cd ..\data_pipeline
az acr login --name <acr-name>
.\scripts\windows\docker\build.ps1
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest
docker push <acr-url>/nyc-taxi-pipeline:latest
```

### 3. Finaliser le déploiement

Retourner dans le conteneur Terraform et finaliser :
```bash
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

## 📚 Documentation

- **[🎓 GUIDE_DEBUTANT.md](./GUIDE_DEBUTANT.md)** - Guide pas à pas pour débutants
- **[WORKFLOW.md](./WORKFLOW.md)** - Guide complet d'utilisation
- **[terraform_pipeline/docs/](./terraform_pipeline/docs/)** - Documentation Terraform
- **[data_pipeline/docs/](./data_pipeline/docs/)** - Documentation Data Pipeline
- **[brief-terraform/BRIEF.md](./brief-terraform/BRIEF.md)** - Instructions originales du brief

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AZURE CLOUD                              │
│                                                                 │
│  ┌──────────────┐     ┌──────────────────┐    ┌──────────────┐  │
│  │   Storage    │     │  Container Apps  │    │  Cosmos DB   │  │
│  │   Account    │───▶│   Environment    │───▶│  PostgreSQL  │  │
│  │  raw/proc    │     │   + Pipeline App │    │   (Citus)    │  │
│  └──────────────┘     └──────────────────┘    └──────────────┘  │
│                              │                                  │
│  ┌──────────────┐     ┌──────┴───────┐                          │
│  │  Container   │     │     Log      │                          │
│  │  Registry    │     │   Analytics  │                          │
│  └──────────────┘     └──────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Prérequis

- Docker Desktop
- Azure CLI
- Compte Azure avec souscription active

## 📖 Pour aller plus loin

- [Workflow complet](./WORKFLOW.md)
- [Architecture détaillée](./terraform_pipeline/docs/architecture.md)
- [Getting Started Data Pipeline](./data_pipeline/docs/getting-started.md)
