# 🏠 Mode Local

Exécution du pipeline avec des émulateurs locaux pour le développement.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         DOCKER                                  │
│                                                                 │
│  ┌──────────────┐     ┌──────────────┐      ┌──────────────┐    │
│  │   Azurite    │     │   Pipeline   │      │  PostgreSQL  │    │
│  │  (Storage)   │◄────│              │────▶│              │    │
│  │  :10000      │     │  Python      │      │  :5432       │    │
│  └──────────────┘     └──────────────┘      └──────────────┘    │
│                              │                                  │
│                              ▼                                  │
│                       ┌──────────────┐                          │
│                       │   PgAdmin    │                          │
│                       │  :5050       │                          │
│                       └──────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

## Services

### Azurite (Émulateur Azure Storage)
- **Port**: 10000 (Blob), 10001 (Queue), 10002 (Table)
- **Connection String**: Fournie automatiquement
- Simule Azure Blob Storage

### PostgreSQL
- **Port**: 5432
- **Database**: nyctaxi
- **User**: postgres
- **Password**: postgres

### PgAdmin (optionnel)
- **URL**: http://localhost:5050
- **Email**: admin@local.dev
- **Password**: admin

## Lancement

### Basique

```powershell
.\scripts\windows\docker\run-local.ps1
```

### Avec options

```powershell
# 3 mois de données
.\scripts\windows\docker\run-local.ps1 -StartDate "2024-01" -EndDate "2024-03"

# Uniquement le téléchargement
.\scripts\windows\docker\run-local.ps1 -Mode download

# Uniquement la transformation
.\scripts\windows\docker\run-local.ps1 -Mode transform

# En arrière-plan avec PgAdmin
.\scripts\windows\docker\run-local.ps1 -Detach -WithTools
```

## Gestion

### Voir les logs

```powershell
# Logs du pipeline
.\scripts\windows\docker\logs.ps1

# Suivre en temps réel
.\scripts\windows\docker\logs.ps1 -Follow

# Logs PostgreSQL
.\scripts\windows\docker\logs.ps1 -Service postgres
```

### Arrêter

```powershell
# Arrêter (garde les données)
.\scripts\windows\docker\stop.ps1

# Arrêter et supprimer les données
.\scripts\windows\docker\stop.ps1 -Clean
```

## Accéder aux données

### Via PgAdmin

1. Lancez avec `-WithTools`
2. Ouvrez http://localhost:5050
3. Connectez-vous (admin@local.dev / admin)
4. Ajoutez un serveur:
   - Host: postgres
   - Port: 5432
   - Database: nyctaxi
   - User: postgres
   - Password: postgres

### Via psql

```bash
docker exec -it nyc-taxi-postgres psql -U postgres -d nyctaxi
```

### Requêtes exemple

```sql
-- Nombre de trajets
SELECT COUNT(*) FROM staging_taxi_trips;

-- Trajets par jour
SELECT 
    DATE(tpep_pickup_datetime) as date,
    COUNT(*) as trips
FROM staging_taxi_trips
GROUP BY 1
ORDER BY 1;
```

## Variables d'environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `START_DATE` | 2024-01 | Date de début |
| `END_DATE` | 2024-01 | Date de fin |
| `PIPELINE_MODE` | all | Mode d'exécution |
| `USE_LOCAL` | true | Utiliser les émulateurs |

## Volumes Docker

| Volume | Contenu |
|--------|---------|
| `postgres-data` | Données PostgreSQL |
| `azurite-data` | Données Blob Storage |
| `pipeline-data` | Fichiers temporaires |
| `pipeline-logs` | Logs du pipeline |

## Troubleshooting

### Le pipeline ne trouve pas les fichiers

Vérifiez que Azurite est bien démarré :
```bash
docker logs nyc-taxi-azurite
```

### Erreur de connexion PostgreSQL

Attendez que PostgreSQL soit prêt :
```bash
docker logs nyc-taxi-postgres
```

### Données manquantes après redémarrage

Les volumes persistent les données. Pour repartir de zéro :
```powershell
.\scripts\windows\docker\stop.ps1 -Clean
```
