# 🚀 Data Pipeline - NYC Taxi

Pipeline de données pour télécharger, charger et transformer les données NYC Taxi.

## 📋 Vue d'ensemble

Ce module permet d'exécuter le pipeline de données :
- **Localement** avec des émulateurs (Azurite, PostgreSQL)
- **Sur Azure** avec les ressources créées par Terraform (via le volume partagé `shared/`)

## 🏗️ Architecture

```
┌──────────────┐      ┌──────────────┐     ┌──────────────┐
│  NYC TLC     │      │   Storage    │     │  PostgreSQL  │
│  (Source)    │────▶│ (Blob/Local) │────▶│   (DuckDB)   │
└──────────────┘      └──────────────┘     └──────────────┘
     │                       │                    │
     │         PIPELINES     │                    │
     │  ┌────────────────────┴────────────────┐   │
     └──│ 1. Download → 2. Load → 3. Transform│───┘
        └─────────────────────────────────────┘
```

## 🚀 Démarrage rapide

### Mode Local (développement)

```powershell
cd data_pipeline

# Construire l'image
.\scripts\windows\docker\build.ps1

# Lancer avec émulateurs locaux (menu interactif)
.\scripts\windows\docker\run-local.ps1
```

### Mode Azure (production)

**Prérequis :** L'infrastructure doit être déployée via `terraform_pipeline` et le fichier `shared/.env.dev` doit exister.

```powershell
# Après avoir déployé l'infrastructure avec terraform_pipeline
.\scripts\windows\docker\run-azure.ps1
```

Le script détecte automatiquement les fichiers `.env` disponibles dans `shared/`.

## 📁 Structure

```
data_pipeline/
├── pipelines/               # Code Python des pipelines
│   ├── ingestion/          # Pipeline 1: Download
│   │   └── download.py     # Télécharge depuis NYC TLC → Azure/Local
│   ├── staging/            # Pipeline 2: Load
│   │   └── load_duckdb.py  # Charge via DuckDB → PostgreSQL
│   └── transformation/     # Pipeline 3: Transform
│       └── transform.py    # Crée le star schema
├── utils/                   # Utilitaires Python
│   ├── database.py         # Connexions PostgreSQL/DuckDB
│   ├── download_helper.py  # Téléchargement fichiers
│   └── parquet_utils.py    # Utilitaires Parquet
├── sql/                     # Scripts SQL
│   ├── create_staging_table.sql  # Crée staging_taxi_trips
│   ├── insert_to.sql            # Insert via DuckDB
│   ├── truncate.sql             # Nettoie la table
│   └── transformations.sql      # Crée DIM et FACT tables
├── docker/
│   ├── Dockerfile           # Image multi-stage avec uv
│   ├── entrypoint.sh        # Script d'entrée
│   ├── docker-compose.yml   # Mode local
│   └── docker-compose.azure.yml  # Mode Azure
├── scripts/
│   ├── windows/docker/      # Scripts PowerShell
│   │   ├── build.ps1        # Construire l'image
│   │   ├── run-local.ps1    # Lancer en local
│   │   ├── run-azure.ps1    # Lancer sur Azure
│   │   ├── update.ps1       # Mettre à jour l'image
│   │   ├── stop.ps1         # Arrêter les conteneurs
│   │   ├── remove.ps1       # Supprimer les ressources
│   │   └── logs.ps1         # Voir les logs
│   └── linux/docker/        # Scripts Bash (mêmes fonctionnalités)
├── docs/                    # Documentation détaillée
├── main.py                  # Point d'entrée
├── pyproject.toml           # Dépendances (uv)
└── uv.lock                  # Lock file des dépendances
```

## 📊 Pipelines et Tables

### Pipeline 1 : Download

Télécharge les fichiers Parquet depuis NYC TLC.

| Mode | Destination |
|------|-------------|
| Local | `data/raw/` (disque local) |
| Azure | Azure Blob Storage (`raw/`) + `data/raw/` (local) |

### Pipeline 2 : Load

Charge les données dans PostgreSQL via DuckDB.

| Source | Destination |
|--------|-------------|
| `data/raw/*.parquet` | `staging_taxi_trips` (PostgreSQL) |

### Pipeline 3 : Transform

Crée le modèle en étoile (Star Schema).

| Table | Type | Description |
|-------|------|-------------|
| `staging_taxi_trips` | Staging | Données brutes |
| `dim_datetime` | Dimension | Dates, heures, périodes |
| `dim_location` | Dimension | Zones géographiques NYC |
| `dim_payment` | Dimension | Types de paiement |
| `dim_vendor` | Dimension | Fournisseurs (CMT, VeriFone) |
| `dim_rate_code` | Dimension | Codes tarifaires (bonus) |
| `fact_trips` | Fait | Métriques des trajets |

## 🔧 Modes d'exécution

### Mode Local

Utilise des émulateurs Docker :
- **Azurite** : Émulateur Azure Storage (port 10000)
- **PostgreSQL** : Base de données locale (port 5432)
- **PgAdmin** : Interface web (port 5050, optionnel)

```powershell
# Lancer avec menu interactif
.\scripts\windows\docker\run-local.ps1

# Lancer avec PgAdmin (option 3 du menu)
```

### Mode Azure

Utilise les ressources déployées par Terraform via le volume partagé :

```
shared/
├── .env.dev    # Généré par terraform apply dev
├── .env.rec    # Généré par terraform apply rec
└── .env.prod   # Généré par terraform apply prod
```

Le fichier `.env` contient :
- `AZURE_STORAGE_CONNECTION_STRING` : Connexion Azure Blob
- `POSTGRES_HOST`, `POSTGRES_PASSWORD` : Connexion PostgreSQL
- `ACR_LOGIN_SERVER`, `ACR_PASSWORD` : Connexion Container Registry
- `START_DATE`, `END_DATE` : Période du pipeline

## 🛠️ Scripts disponibles

### Windows (PowerShell)

| Script | Description |
|--------|-------------|
| `build.ps1` | Construire l'image Docker (menu interactif) |
| `run-local.ps1` | Lancer en mode local |
| `run-azure.ps1` | Lancer en mode Azure |
| `update.ps1` | Mettre à jour l'image |
| `stop.ps1` | Arrêter les conteneurs |
| `remove.ps1` | Supprimer conteneurs/volumes/images |
| `logs.ps1` | Voir les logs |

### Linux (Bash)

Mêmes fonctionnalités dans `scripts/linux/docker/`.

```bash
./scripts/linux/docker/build.sh
./scripts/linux/docker/run-local.sh
./scripts/linux/docker/run-azure.sh
./scripts/linux/docker/stop.sh
```

## 🔗 Intégration avec Terraform

### Volume partagé

Le dossier `shared/` à la racine du projet sert de pont entre les deux modules :

1. **terraform_pipeline** génère les fichiers `.env`:
   - `apply dev` → crée `shared/.env.dev`
   - `destroy dev` → supprime `shared/.env.dev`

2. **data_pipeline** lit les fichiers `.env`:
   - `run-azure.sh` → utilise `shared/.env.dev`

### Workflow complet

```bash
# 1. Déployer l'infrastructure (génère shared/.env.dev)
cd terraform_pipeline
./scripts/linux/docker/run.sh
apply dev
exit

# 2. Exécuter le pipeline (utilise shared/.env.dev)
cd ../data_pipeline
./scripts/linux/docker/run-azure.sh
```

## 📚 Documentation

- [Getting Started](./docs/getting-started.md) - Premiers pas
- [Mode Local](./docs/local-mode.md) - Utilisation locale
- [Mode Azure](./docs/azure-mode.md) - Utilisation Azure
- [Scripts](./docs/scripts.md) - Détail des scripts
- [Troubleshooting](./docs/troubleshooting.md) - Résolution de problèmes

## 🔗 Liens

- [Terraform Pipeline](../terraform_pipeline/) - Infrastructure Azure
- [Guide Débutant](../GUIDE_DEBUTANT.md) - Guide pas à pas complet
- [Brief](../brief-terraform/BRIEF.md) - Instructions originales
