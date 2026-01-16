# ☁️ Mode Azure

Exécution du pipeline sur les ressources Azure déployées via Terraform.

## Prérequis

1. **Infrastructure déployée** via `terraform_pipeline` (avec `apply dev`)
2. **Fichier .env généré** dans `shared/.env.dev` (automatique après `apply`)
3. **Image Docker** construite

## Volume partagé

Le projet utilise un **volume partagé** (`shared/`) pour la communication entre Terraform et le pipeline :

```
Brief_Terraform_2/
├── shared/                    # Volume partagé
│   ├── .env.dev              # Généré par "apply dev"
│   ├── .env.rec              # Généré par "apply rec"
│   └── .env.prod             # Généré par "apply prod"
├── terraform_pipeline/        # Génère les .env
└── data_pipeline/             # Utilise les .env
```

### Contenu du fichier .env

```bash
# Azure Storage
AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=https;...
AZURE_CONTAINER_NAME=raw

# PostgreSQL
POSTGRES_HOST=c-xxx.postgres.cosmos.azure.com
POSTGRES_PORT=5432
POSTGRES_DB=citus
POSTGRES_USER=citus
POSTGRES_PASSWORD=xxx
POSTGRES_SSL_MODE=require

# Container Registry
ACR_LOGIN_SERVER=xxx.azurecr.io
ACR_USERNAME=xxx
ACR_PASSWORD=xxx

# Pipeline Config
START_DATE=2024-01
END_DATE=2024-02
```

## Workflow complet

```
┌─────────────┐      ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Terraform  │      │ Build Image │     │  Run Azure  │     │   Verify    │
│ apply dev   │────▶│   Locally   │────▶│   Pipeline  │────▶│   Data      │
│ (génère     │      └─────────────┘     │ (lit .env)  │     └─────────────┘
│  .env.dev)  │                          └─────────────┘
└─────────────┘
```

## Étape 1 : Déployer l'infrastructure

```powershell
cd terraform_pipeline
.\scripts\windows\docker\run.ps1
```

Dans le conteneur Terraform :
```bash
# Commande simplifiée (génère automatiquement shared/.env.dev)
apply dev
```

## Étape 2 : Construire l'image

```powershell
cd data_pipeline
.\scripts\windows\docker\build.ps1
```

## Étape 3 : Lancer le pipeline

```powershell
.\scripts\windows\docker\run-azure.ps1
```

Le script affiche un menu avec les environnements disponibles :

```
[STATUS] Fichiers .env disponibles:
  ✓ .env.dev (modifié: 2026-01-15)
  ✗ .env.rec (non trouvé)
  ✗ .env.prod (non trouvé)

Choisissez un environnement :
  1) dev  - Développement
  2) rec  - Recette
  3) prod - Production
```

## Options du script

### Menu interactif

```powershell
.\scripts\windows\docker\run-azure.ps1
```

### Mode automatique

```powershell
# Environnement dev, période personnalisée
.\scripts\windows\docker\run-azure.ps1 -Env dev -StartDate "2024-01" -EndDate "2024-06"

# Mode spécifique (download, load, transform, all)
.\scripts\windows\docker\run-azure.ps1 -Env dev -Mode download
```

## Vérification

### Via Azure Portal

1. Ouvrez le Resource Group `fabadiRG`
2. Storage Account → Containers → `raw`
3. Vérifiez les fichiers Parquet

### Via Azure CLI

```bash
# Récupérer le nom du storage depuis .env
source shared/.env.dev

# Lister les fichiers
az storage blob list \
  --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
  --container-name raw \
  --output table
```

### Via PostgreSQL

```bash
# Utiliser les variables du .env
source shared/.env.dev

# Se connecter
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=${POSTGRES_SSL_MODE}"
```

```sql
-- Vérifier toutes les tables du star schema
SELECT 'staging_taxi_trips' AS table_name, COUNT(*) FROM staging_taxi_trips
UNION ALL SELECT 'dim_datetime', COUNT(*) FROM dim_datetime
UNION ALL SELECT 'dim_location', COUNT(*) FROM dim_location
UNION ALL SELECT 'dim_payment', COUNT(*) FROM dim_payment
UNION ALL SELECT 'dim_vendor', COUNT(*) FROM dim_vendor
UNION ALL SELECT 'fact_trips', COUNT(*) FROM fact_trips;

-- Exemple : Revenus par jour de semaine
SELECT 
    d.jour_semaine_nom,
    COUNT(*) as nb_courses,
    AVG(f.montant_total) as revenu_moyen
FROM fact_trips f
JOIN dim_datetime d ON f.pickup_datetime_key = d.date_complete
GROUP BY d.jour_semaine_nom
ORDER BY nb_courses DESC;
```

## Alternative : Container Apps

Le pipeline peut s'exécuter directement dans Azure Container Apps :

```bash
# Voir les logs
az containerapp logs show \
  --name ca-nyctaxi-pipeline-dev \
  --resource-group fabadiRG \
  --follow

# Redémarrer le Container App
az containerapp revision restart \
  --name ca-nyctaxi-pipeline-dev \
  --resource-group fabadiRG
```

## Troubleshooting

### "Fichier .env non trouvé"

**Cause :** L'infrastructure n'a pas été déployée ou le fichier n'a pas été généré.

**Solution :**
```bash
# Dans le conteneur Terraform
apply dev
# ou
genenv dev  # Pour régénérer sans apply
```

### "Connection refused" PostgreSQL

**Cause :** Firewall PostgreSQL.

**Solution :** En dev/rec, le firewall autorise maintenant toutes les IPs. Si l'erreur persiste, vérifiez le mot de passe dans `shared/.env.dev`.

### "Aucun fichier Parquet trouvé"

**Cause :** Le pipeline 1 (download) n'a pas sauvegardé les fichiers localement.

**Solution :** Vérifiez que vous utilisez la dernière version du code. Le pipeline sauvegarde maintenant les fichiers localement ET sur Azure.

### Timeout sur gros volumes

Pour plus de 6 mois de données :
1. Augmentez les ressources Container App
2. Ou exécutez par lots (ex: 3 mois à la fois)
