# 📚 Documentation - Data Pipeline

Pipeline de données pour le téléchargement, chargement et transformation des données NYC Taxi.

## 📖 Table des matières

| Document | Description |
|----------|-------------|
| [Getting Started](./getting-started.md) | Guide de démarrage rapide |
| [Local Mode](./local-mode.md) | Exécution locale avec émulateurs |
| [Azure Mode](./azure-mode.md) | Exécution sur ressources Azure |
| [Scripts](./scripts.md) | Documentation des scripts |
| [Troubleshooting](./troubleshooting.md) | Résolution des problèmes |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA PIPELINE                                │
│                                                                 │
│  ┌──────────────┐      ┌──────────────┐     ┌──────────────┐    │
│  │  Pipeline 1  │      │  Pipeline 2  │     │  Pipeline 3  │    │
│  │   DOWNLOAD   │────▶│     LOAD     │────▶│  TRANSFORM   │    │
│  │              │      │              │     │              │    │
│  │  NYC TLC     │      │  DuckDB      │     │  Star Schema │    │
│  │  → Storage   │      │  → PostgreSQL│     │  Dimensions  │    │
│  └──────────────┘      └──────────────┘     └──────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## 🔗 Intégration avec Terraform

Ce pipeline utilise un **volume partagé** (`shared/`) avec `terraform_pipeline` :

```
Brief_Terraform_2/
├── shared/                  # Volume partagé
│   ├── .env.dev            # Variables pour l'env dev
│   ├── .env.rec            # Variables pour l'env rec
│   └── .env.prod           # Variables pour l'env prod
├── terraform_pipeline/      # Génère les fichiers .env
└── data_pipeline/           # Utilise les fichiers .env
```

**Workflow :**
1. `terraform apply dev` → crée `shared/.env.dev`
2. `run-azure.sh` → lit `shared/.env.dev`

## 🚀 Démarrage rapide

### Mode Local (développement)

```powershell
cd data_pipeline
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run-local.ps1
```

### Mode Azure (production)

```powershell
# 1. Déployer l'infrastructure avec Terraform
cd terraform_pipeline
.\scripts\windows\docker\run.ps1
# Dans le conteneur:
apply dev
exit

# 2. Lancer le pipeline sur Azure (lit shared/.env.dev)
cd ..\data_pipeline
.\scripts\windows\docker\run-azure.ps1
```

## 📁 Structure

```
data_pipeline/
├── pipelines/               # Code Python
│   ├── ingestion/          # Pipeline 1: Download
│   ├── staging/            # Pipeline 2: Load
│   └── transformation/     # Pipeline 3: Transform
├── utils/                   # Utilitaires
├── sql/                     # Scripts SQL
├── docker/
│   ├── Dockerfile           # Image du pipeline
│   ├── entrypoint.sh        # Script d'entrée
│   └── docker-compose.yml   # Orchestration locale
├── scripts/
│   ├── windows/docker/      # Scripts PowerShell
│   └── linux/docker/        # Scripts Bash
├── docs/                    # Documentation
└── README.md
```

## 🔧 Modes d'exécution

| Mode | Description | Fichier de config |
|------|-------------|-------------------|
| **Local** | PostgreSQL + Azurite locaux | `.env` (docker-compose) |
| **Azure** | Ressources Azure | `shared/.env.{env}` |

## 📊 Tables créées (Star Schema)

### Tables de dimensions

| Table | Description |
|-------|-------------|
| `dim_datetime` | Dates, heures, périodes de la journée |
| `dim_location` | Zones géographiques NYC |
| `dim_payment` | Types de paiement (carte, espèces...) |
| `dim_vendor` | Fournisseurs (CMT, VeriFone) |
| `dim_rate_code` | Codes tarifaires (bonus) |

### Table de faits

| Table | Description |
|-------|-------------|
| `staging_taxi_trips` | Données brutes chargées |
| `fact_trips` | Métriques des trajets (montants, distances, durées...) |

## 🛠️ Scripts disponibles

### Windows

```powershell
.\scripts\windows\docker\build.ps1      # Construire l'image
.\scripts\windows\docker\run-local.ps1  # Mode local
.\scripts\windows\docker\run-azure.ps1  # Mode Azure
.\scripts\windows\docker\update.ps1     # Mettre à jour l'image
.\scripts\windows\docker\stop.ps1       # Arrêter
.\scripts\windows\docker\remove.ps1     # Supprimer
.\scripts\windows\docker\logs.ps1       # Voir les logs
```

### Linux

```bash
./scripts/linux/docker/build.sh
./scripts/linux/docker/run-local.sh
./scripts/linux/docker/run-azure.sh
./scripts/linux/docker/stop.sh
```
