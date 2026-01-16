# 🐛 Troubleshooting - Data Pipeline

## Erreurs courantes

### "Cannot connect to Docker daemon"

**Cause**: Docker Desktop n'est pas démarré.

**Solution**:
```powershell
# Démarrer Docker Desktop
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

---

### "No such file or directory: Dockerfile"

**Cause**: Mauvais répertoire de travail.

**Solution**:
```powershell
cd data_pipeline
.\scripts\windows\docker\build.ps1
```

---

### "Connection refused" PostgreSQL (mode local)

**Cause**: PostgreSQL n'est pas prêt.

**Solution**: Attendez quelques secondes, le healthcheck vérifie automatiquement.

```powershell
# Vérifier l'état
docker logs nyc-taxi-postgres
```

---

### "Terraform non initialisé" (mode Azure)

**Cause**: L'infrastructure n'a pas été déployée.

**Solution**:
```powershell
cd terraform_pipeline
.\scripts\windows\docker\run.ps1
# Dans le conteneur:
terraform init
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

---

### Téléchargement très lent

**Cause**: Fichiers Parquet volumineux (~100 MB/mois).

**Solutions**:
- Réduire la période (`-EndDate` proche de `-StartDate`)
- Utiliser le mode `download` seul d'abord

---

### "SSL required" (mode Azure)

**Cause**: Connexion PostgreSQL sans SSL.

**Solution**: Le script configure automatiquement `POSTGRES_SSL_MODE=require`. Si l'erreur persiste, vérifiez les variables d'environnement.

---

### Données manquantes après redémarrage

**Cause**: Volumes Docker supprimés.

**Solution**: Ne pas utiliser `-Clean` sauf si nécessaire.

```powershell
# Garder les données
.\scripts\windows\docker\stop.ps1

# Supprimer les données (reset)
.\scripts\windows\docker\stop.ps1 -Clean
```

---

### PgAdmin ne se connecte pas

**Cause**: Mauvaise configuration du serveur.

**Solution** dans PgAdmin:
- Host: `postgres` (pas localhost)
- Port: `5432`
- Database: `nyctaxi`
- User: `postgres`
- Password: `postgres`

---

## Commandes de diagnostic

### État des conteneurs

```powershell
docker ps -a
```

### Logs détaillés

```powershell
.\scripts\windows\docker\logs.ps1 -Service all -Lines 200
```

### Espace disque Docker

```bash
docker system df
```

### Nettoyer Docker

```bash
# Supprimer les ressources non utilisées
docker system prune -a

# Supprimer les volumes orphelins
docker volume prune
```

## Vérifier les données

### Mode local - PostgreSQL

```bash
docker exec -it nyc-taxi-postgres psql -U postgres -d nyctaxi -c "SELECT COUNT(*) FROM staging_taxi_trips;"
```

### Mode local - Azurite

```bash
# Lister les blobs (nécessite Azure CLI)
az storage blob list \
  --connection-string "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1" \
  --container-name raw \
  --output table
```
