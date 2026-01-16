# 🚕 NYC Taxi Data Pipeline - Infrastructure & Data Engineering

[![Terraform CI](https://github.com/YOUR_USERNAME/Brief_Terraform_2/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/Brief_Terraform_2/actions/workflows/terraform-ci.yml)
[![Data Pipeline CI](https://github.com/YOUR_USERNAME/Brief_Terraform_2/actions/workflows/data-pipeline-ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/Brief_Terraform_2/actions/workflows/data-pipeline-ci.yml)

> Infrastructure as Code avec Terraform pour déployer un pipeline de données complet sur Azure, analysant les données historiques des taxis de New York.

## 📋 Table des matières

- [Contexte du projet](#-contexte-du-projet)
- [Architecture](#-architecture)
- [Technologies utilisées](#-technologies-utilisées)
- [Prérequis](#-prérequis)
- [Installation rapide](#-installation-rapide)
- [Structure du projet](#-structure-du-projet)
- [Infrastructure Terraform](#-infrastructure-terraform)
- [Pipeline de données](#-pipeline-de-données)
- [Modèle de données (Star Schema)](#-modèle-de-données-star-schema)
- [CI/CD](#-cicd)
- [Troubleshooting](#-troubleshooting)
- [Coûts Azure estimés](#-coûts-azure-estimés)
- [Documentation](#-documentation)

---

## 🎯 Contexte du projet

En tant que **Data Engineer** dans une startup de mobilité urbaine, ce projet met en place une infrastructure cloud permettant d'analyser les données historiques des taxis de New York (NYC TLC).

**Objectifs :**
- ✅ Déployer une infrastructure Azure reproductible avec Terraform
- ✅ Construire un pipeline de données automatisé (Download → Load → Transform)
- ✅ Créer un modèle en étoile (Star Schema) dans PostgreSQL
- ✅ Containeriser l'application avec Docker
- ✅ Implémenter les bonnes pratiques DevOps

**Dataset utilisé :**
- Source : [NYC Taxi & Limousine Commission](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)
- Format : Parquet
- Taille : ~2-4 millions de trajets/mois
- URL Pattern : `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`

---

## 🏗 Architecture

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                              AZURE CLOUD                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐    │
│  │                     Resource Group: fabadiRG                          │    │
│  │                                                                       │    │
│  │   ┌───────────────┐    ┌──────────────┐    ┌──────────────────────┐   │    │
│  │   │   Storage     │    │  Container   │    │   Cosmos DB for      │   │    │
│  │   │   Account     │    │  Registry    │    │   PostgreSQL         │   │    │
│  │   │               │    │   (ACR)      │    │   (Citus)            │   │    │
│  │   │  ┌─────────┐  │    │              │    │                      │   │    │
│  │   │  │  raw    │  │    │  Pipeline    │    │  ┌────────────────┐  │   │    │
│  │   │  ├─────────┤  │    │  Image       │    │  │ staging_trips  │  │   │    │
│  │   │  │processed│  │    │              │    │  │ dim_datetime   │  │   │    │
│  │   │  └─────────┘  │    │              │    │  │ dim_location   │  │   │    │
│  │   └───────────────┘    └──────────────┘    │  │ dim_payment    │  │   │    │
│  │          │                   │             │  │ dim_vendor     │  │   │    │
│  │          │                   │             │  │ dim_rate_code  │  │   │    │
│  │          ▼                   ▼             │  │ fact_trips     │  │   │    │
│  │   ┌─────────────────────────────────┐      │  └────────────────┘  │   │    │
│  │   │     Container Apps Environment  │      └──────────────────────┘   │    │
│  │   │     ┌─────────────────────┐     │               ▲                 │    │
│  │   │     │  NYC Taxi Pipeline  │─────┼───────────────┘                 │    │
│  │   │     │  (Container App)    │     │                                 │    │
│  │   │     └─────────────────────┘     │                                 │    │
│  │   └─────────────────────────────────┘                                 │    │
│  │                    │                                                  │    │
│  │   ┌────────────────┴────────────────┐                                 │    │
│  │   │       Log Analytics             │                                 │    │
│  │   │       (Monitoring)              │                                 │    │
│  │   └─────────────────────────────────┘                                 │    │
│  └───────────────────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────────────────┘

                              DATA FLOW
                              ─────────
    ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐
    │  NYC    │      │ Pipeline│      │ Pipeline│      │ Pipeline│
    │  TLC    │ ───▶│    1    │  ───▶│    2    │ ───▶│    3    │
    │  API    │      │Download │      │  Load   │      │Transform│
    └─────────┘      └─────────┘      └─────────┘      └─────────┘
         │               │                 │                │
         │               ▼                 ▼                ▼
         │           ┌─────────┐      ┌──────────┐      ┌─────────┐
         │           │  Blob   │      │PostgreSQL│      │  Star   │
         └─────────▶│  raw/   │      │ staging  │      │ Schema  │
                     └─────────┘      └──────────┘      └─────────┘
```

---

## 🛠 Technologies utilisées

| Catégorie | Technologie | Version | Description |
|-----------|-------------|---------|-------------|
| **IaC** | Terraform | 1.7.0 | Infrastructure as Code |
| **Cloud** | Azure | - | Plateforme cloud |
| **Container** | Docker | 24+ | Containerisation |
| **Language** | Python | 3.11 | Pipeline de données |
| **Database** | PostgreSQL | 15+ | Cosmos DB for PostgreSQL |
| **Processing** | DuckDB | 0.9+ | Traitement analytique |
| **Package Manager** | uv | latest | Gestionnaire Python rapide |

**Services Azure déployés :**
- Azure Storage Account (Blob)
- Azure Container Registry (ACR)
- Azure Cosmos DB for PostgreSQL
- Azure Container Apps
- Azure Log Analytics

---

## 📦 Prérequis

### Logiciels requis

| Logiciel | Version minimale | Installation |
|----------|------------------|--------------|
| Docker Desktop | 4.0+ | [docker.com](https://www.docker.com/products/docker-desktop) |
| Git | 2.30+ | [git-scm.com](https://git-scm.com/) |
| Azure CLI | 2.50+ | Inclus dans le conteneur |
| Terraform | 1.7.0 | Inclus dans le conteneur |

### Compte Azure

- Souscription Azure active
- Droits pour créer des ressources
- Resource Group existant ou droits pour en créer

---

## 🚀 Installation rapide

### Étape 1 : Cloner le projet

```bash
git clone https://github.com/YOUR_USERNAME/Brief_Terraform_2.git
cd Brief_Terraform_2
```

### Étape 2 : Déployer l'infrastructure

```powershell
# Windows
cd terraform_pipeline
.\scripts\windows\docker\build.ps1    # Choisir option 1 ou 2
.\scripts\windows\docker\run.ps1
```

```bash
# Linux/Mac
cd terraform_pipeline
./scripts/linux/docker/build.sh
./scripts/linux/docker/run.sh
```

### Étape 3 : Dans le conteneur Terraform

```bash
# Se connecter à Azure
az login --use-device-code

# Déployer l'environnement dev
apply dev

# Vérifier les outputs
output
```

### Étape 4 : Exécuter le pipeline de données

```bash
# Depuis un nouveau terminal
cd data_pipeline

# Linux/WSL
./scripts/linux/docker/build.sh
./scripts/linux/docker/run-azure.sh   # Choisir dev

# Windows PowerShell
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run-azure.ps1
```

---

## 📁 Structure du projet

```
Brief_Terraform_2/
│
├── 📂 terraform_pipeline/          # Infrastructure Terraform
│   ├── 📂 terraform/
│   │   ├── 📂 modules/storage/     # Module Storage Account
│   │   ├── 📂 environments/        # dev.tfvars, rec.tfvars, prod.tfvars
│   │   ├── 📂 scripts/             # apply.sh, destroy.sh, generate-env.sh
│   │   ├── main.tf                 # Ressources principales
│   │   ├── variables.tf            # Variables Terraform
│   │   ├── outputs.tf              # Outputs Terraform
│   │   └── providers.tf            # Configuration providers
│   ├── 📂 docker/
│   │   ├── Dockerfile              # Image Terraform + Azure CLI
│   │   └── entrypoint.sh           # Script d'entrée interactif
│   ├── 📂 scripts/                 # Scripts Windows/Linux
│   └── 📂 docs/                    # Documentation Terraform
│
├── 📂 data_pipeline/               # Pipeline de données
│   ├── 📂 pipelines/
│   │   ├── 📂 ingestion/           # Pipeline 1: Download
│   │   ├── 📂 staging/             # Pipeline 2: Load
│   │   └── 📂 transformation/      # Pipeline 3: Transform
│   ├── 📂 sql/
│   │   ├── create_staging_table.sql
│   │   └── transformations.sql     # Star Schema
│   ├── 📂 docker/
│   │   ├── Dockerfile              # Multi-stage build optimisé
│   │   └── docker-compose.yml
│   ├── 📂 scripts/                 # Scripts Windows/Linux
│   ├── main.py                     # Point d'entrée
│   └── pyproject.toml              # Dépendances (uv)
│
├── 📂 shared/                      # Volume partagé (généré)
│   └── .env.dev                    # Variables d'environnement (généré par Terraform)
│
├── 📂 .github/workflows/           # CI/CD GitHub Actions
│   ├── terraform-ci.yml
│   └── data-pipeline-ci.yml
│
├── README.md                       # Ce fichier
├── GUIDE_DEBUTANT.md              # Guide pas à pas
└── .gitignore
```

---

## ⚙️ Infrastructure Terraform

### Ressources déployées

| Ressource | Nom | Description |
|-----------|-----|-------------|
| Storage Account | `stnyctaxi{env}{suffix}` | Blob Storage (raw, processed) |
| Container Registry | `acrnyctaxi{env}{suffix}` | Registry Docker privé |
| Cosmos DB PostgreSQL | `c-nyctaxi-{env}-{suffix}` | Base de données (star schema) |
| Container Apps Environment | `cae-nyctaxi-{env}` | Environnement d'orchestration |
| Container App | `ca-nyctaxi-pipeline-{env}` | Application du pipeline |
| Log Analytics | `log-nyctaxi-{env}` | Monitoring et logs |

### Variables d'environnement

Les fichiers `environments/*.tfvars` contiennent :

```hcl
# dev.tfvars
environment    = "dev"
project_name   = "nyctaxi"
location       = "francecentral"
acr_sku        = "Basic"
postgres_allow_all_ips = true  # Pour développement uniquement
```

### Commandes Terraform simplifiées

Dans le conteneur Terraform :

```bash
plan dev      # Prévisualiser les changements
apply dev     # Déployer + générer .env.dev
destroy dev   # Supprimer les ressources
genenv dev    # Régénérer le .env sans redéployer
ca dev        # Commandes Container App
output        # Voir les outputs
tfhelp        # Aide complète
```

---

## 🔄 Pipeline de données

### Pipeline 1 : Download (Ingestion)

```python
# Télécharge les fichiers Parquet depuis NYC TLC
# → Upload vers Azure Blob Storage (raw/)
# → Sauvegarde locale pour Pipeline 2
```

### Pipeline 2 : Load (Staging)

```python
# Lit les fichiers Parquet locaux avec DuckDB
# → Charge dans PostgreSQL (staging_taxi_trips)
# → Utilise l'extension postgres_scanner de DuckDB
```

### Pipeline 3 : Transform (Star Schema)

```sql
-- Crée les tables de dimension et de faits
-- dim_datetime, dim_location, dim_payment, dim_vendor, dim_rate_code
-- fact_trips (table de faits avec clés étrangères)
```

---

## ⭐ Modèle de données (Star Schema)

```
                    ┌─────────────────┐
                    │  dim_datetime   │
                    │─────────────────│
                    │ datetime_key PK │
                    │ date_complete   │
                    │ annee           │
                    │ mois            │
                    │ jour            │
                    │ heure           │
                    │ jour_semaine    │
                    │ est_weekend     │
                    └────────┬────────┘
                             │
┌─────────────────┐          │          ┌─────────────────┐
│  dim_location   │          │          │   dim_vendor    │
│─────────────────│          │          │─────────────────│
│ location_key PK │          │          │ vendor_key PK   │
│ location_id     │          │          │ vendor_id       │
│ borough         │          │          │ vendor_name     │
│ zone            │          │          └────────┬────────┘
│ service_zone    │          │                   │
└────────┬────────┘          │                   │
         │     ┌─────────────┴───────────────────┤
         │     │                                 │
         │     │     ┌─────────────────────┐     │
         │     │     │     fact_trips      │     │
         │     │     │─────────────────────│     │
         └─────┼────▶│ trip_id PK         │◀────┘
               │     │ pickup_datetime_key │◀───────────┐
               │     │ pickup_location_key │             │
               │     │ dropoff_location_key│             │
               │     │ vendor_key          │             │
               │     │ payment_key         │◀───┐       │
               │     │ rate_code_key       │◀─┐ │       │
               │     │─────────────────────│   │ │       │
               │     │ passenger_count     │   │ │       │
               │     │ trip_distance       │   │ │       │
               │     │ fare_amount         │   │ │       │
               │     │ tip_amount          │   │ │       │
               │     │ total_amount        │   │ │       │
               │     └─────────────────────┘   │ │       │
               │                               │ │       │
               │     ┌─────────────────┐       │ │       │
               │     │ dim_rate_code   │───────┘ │       │
               │     │─────────────────│         │       │
               │     │ rate_code_key PK│         │       │
               │     │ rate_code_id    │         │       │
               │     │ rate_code_name  │         │       │
               │     └─────────────────┘         │       │
               │                                 │       │
               │     ┌─────────────────┐         │       │
               │     │  dim_payment    │─────────┘       │
               │     │─────────────────│                 │
               │     │ payment_key PK  │                 │
               │     │ payment_type_id │                 │
               │     │ payment_name    │                 │
               │     └─────────────────┘                 │
               │                                         │
               └─────────────────────────────────────────┘
```

---

## 🔄 CI/CD

### GitHub Actions Workflows

**Terraform CI** (`.github/workflows/terraform-ci.yml`) :
- ✅ Format check (`terraform fmt`)
- ✅ Validation (`terraform validate`)
- ✅ Security scan (tfsec)
- ✅ Plan (sur PR)

**Data Pipeline CI** (`.github/workflows/data-pipeline-ci.yml`) :
- ✅ Python lint (ruff, black, isort)
- ✅ Syntax check
- ✅ Docker build
- ✅ Documentation check

---

## 🔧 Troubleshooting

### Erreur : "ImagePullBackOff" sur Container App

**Cause** : L'image Docker n'existe pas encore dans ACR.

**Solution** :
```bash
# Depuis data_pipeline
./scripts/linux/docker/build.sh --deploy dev
```

### Erreur : "Connection refused" PostgreSQL

**Cause** : Firewall bloque l'IP locale.

**Solution** : Vérifier que `postgres_allow_all_ips = true` dans `dev.tfvars`.

### Erreur : "Provider not registered"

**Cause** : Les providers Azure ne sont pas enregistrés.

**Solution** : Le script d'entrée les enregistre automatiquement. Attendez 1-2 min.

### Erreur : "Permission denied" sur .env.dev

**Cause** : Fichier créé avec permissions restrictives.

**Solution** :
```bash
# WSL
chmod 644 /mnt/c/.../shared/.env.dev

# Ou supprimer et régénérer depuis le conteneur Terraform
genenv dev
```

### Erreur : Docker "error getting credentials"

**Cause** : Configuration Docker corrompue.

**Solution** :
```powershell
Remove-Item ~/.docker/config.json -Force
docker login
```

---

## 💰 Coûts Azure estimés

| Ressource | SKU | Coût estimé/mois |
|-----------|-----|------------------|
| Storage Account | Standard LRS | ~$1-5 |
| Container Registry | Basic | ~$5 |
| Cosmos DB PostgreSQL | Burstable 1 vCore | ~$30-50 |
| Container Apps | Consumption | Pay-per-use (~$0-10) |
| Log Analytics | Pay-as-you-go | ~$2-5 |
| **TOTAL estimé** | | **~$40-75/mois** |

> 💡 **Conseil** : Utilisez `destroy dev` pour supprimer les ressources quand vous ne travaillez pas.

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [GUIDE_DEBUTANT.md](./GUIDE_DEBUTANT.md) | Guide pas à pas pour débutants |
| [terraform_pipeline/README.md](./terraform_pipeline/README.md) | Documentation Terraform |
| [terraform_pipeline/docs/](./terraform_pipeline/docs/) | Documentation détaillée Terraform |
| [data_pipeline/README.md](./data_pipeline/README.md) | Documentation Data Pipeline |
| [data_pipeline/docs/](./data_pipeline/docs/) | Documentation détaillée Pipeline |

---

## 👤 Auteur

- **Projet** : Brief Terraform - NYC Taxi Pipeline
- **Formation** : Data Engineer

---

## 📝 Licence

Ce projet est réalisé dans un cadre pédagogique.

---

## ✅ Checklist de validation

- [x] Infrastructure Terraform déployable sans erreur
- [x] Pipeline Python fonctionnel localement
- [x] Pipeline exécuté avec succès sur Azure
- [x] Star Schema créé dans PostgreSQL
- [x] Images Docker multi-stage optimisées
- [x] Documentation complète
- [x] CI/CD configuré
