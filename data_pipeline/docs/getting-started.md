# 🚀 Getting Started - Data Pipeline

## Prérequis

- Docker Desktop installé et en cours d'exécution
- (Pour Azure) Infrastructure déployée via `terraform_pipeline`
- Le projet est **autonome** avec son propre code Python

## Mode Local

Le mode local utilise des émulateurs pour tester sans Azure :
- **Azurite** : Émulateur Azure Storage
- **PostgreSQL** : Base de données locale

### Étape 1: Construire l'image

```powershell
cd data_pipeline
.\scripts\windows\docker\build.ps1
```

### Étape 2: Lancer le pipeline

```powershell
# Télécharger 1 mois de données
.\scripts\windows\docker\run-local.ps1 -StartDate "2024-01" -EndDate "2024-01"

# Avec PgAdmin pour visualiser les données
.\scripts\windows\docker\run-local.ps1 -WithTools
```

### Étape 3: Voir les logs

```powershell
.\scripts\windows\docker\logs.ps1 -Follow
```

### Étape 4: Arrêter

```powershell
.\scripts\windows\docker\stop.ps1

# Supprimer les données
.\scripts\windows\docker\stop.ps1 -Clean
```

## Mode Azure

### Prérequis

1. Infrastructure déployée via Terraform
2. Image poussée vers ACR (ou utiliser l'image locale)

### Étape 1: Vérifier l'infrastructure

```powershell
cd terraform_pipeline
.\scripts\windows\docker\run.ps1
# Dans le conteneur:
terraform output
```

### Étape 2: Lancer le pipeline

```powershell
cd data_pipeline
.\scripts\windows\docker\run-azure.ps1 -Env dev -StartDate "2024-01" -EndDate "2024-03"
```

## Options des scripts

### run-local.ps1

| Option | Description |
|--------|-------------|
| `-StartDate` | Date de début (YYYY-MM) |
| `-EndDate` | Date de fin (YYYY-MM) |
| `-Mode` | download, load, transform, all |
| `-Detach` | Lancer en arrière-plan |
| `-WithTools` | Inclure PgAdmin |

### run-azure.ps1

| Option | Description |
|--------|-------------|
| `-Env` | Environnement: dev, rec, prod |
| `-StartDate` | Date de début (YYYY-MM) |
| `-EndDate` | Date de fin (YYYY-MM) |
| `-Mode` | download, load, transform, all |

## Accès aux outils (mode local)

| Outil | URL | Credentials |
|-------|-----|-------------|
| PgAdmin | http://localhost:5050 | admin@local.dev / admin |
| PostgreSQL | localhost:5432 | postgres / postgres |
| Azurite Blob | localhost:10000 | - |

## Prochaines étapes

- [Mode Local détaillé](./local-mode.md)
- [Mode Azure détaillé](./azure-mode.md)
- [Troubleshooting](./troubleshooting.md)
