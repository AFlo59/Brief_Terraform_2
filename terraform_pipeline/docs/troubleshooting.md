# 🐛 Troubleshooting

Guide de résolution des problèmes courants.

## Erreurs Docker

### "Cannot connect to the Docker daemon"

**Symptôme**:
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Causes**:
- Docker Desktop n'est pas démarré
- Problème de permissions

**Solutions**:
```powershell
# Windows - Démarrer Docker Desktop
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Vérifier le statut
docker info
```

```bash
# Linux - Démarrer le service
sudo systemctl start docker

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
# Puis déconnecter/reconnecter
```

### "Image not found"

**Symptôme**:
```
Error response from daemon: pull access denied for terraform-azure-workspace
```

**Solution**:
```powershell
# Construire l'image localement
.\scripts\windows\docker\build.ps1
```

---

## Erreurs Azure CLI

### "az login" échoue dans le conteneur

**Symptôme**:
```
A web browser has been opened at https://login.microsoftonline.com/...
Unable to open browser
```

**Cause**: Pas de navigateur dans le conteneur Docker.

**Solution**:
```bash
# Utiliser le mode device-code
az login --use-device-code
```

1. Ouvrez https://microsoft.com/devicelogin dans votre navigateur
2. Entrez le code affiché
3. Connectez-vous avec votre compte Azure

### "AADSTS... error"

**Symptôme**:
```
AADSTS50076: Due to a configuration change made by your administrator...
```

**Solution**:
```bash
# Forcer une nouvelle authentification
az logout
az login --use-device-code
```

### "The subscription ... could not be found"

**Symptôme**:
```
The subscription '...' could not be found
```

**Solutions**:
```bash
# Lister les souscriptions disponibles
az account list --output table

# Sélectionner la bonne souscription
az account set --subscription "Nom de la souscription"
```

---

## Erreurs Terraform

### "Error: Invalid SKU for server edition"

**Symptôme**:
```
Error: creating Cosmos DB PostgreSQL Cluster: InvalidSkuForServerEdition
```

**Cause**: Utilisation de GeneralPurpose avec 1 vCore (non supporté).

**Solution**: Le code utilise déjà `BurstableMemoryOptimized`. Vérifiez que vous utilisez bien les fichiers `.tfvars` fournis.

### "Error: Resource already exists"

**Symptôme**:
```
Error: A resource with the ID "..." already exists
```

**Solutions**:
```bash
# Option 1: Importer la ressource existante
terraform import <resource_type>.<name> <azure_resource_id>

# Option 2: Supprimer la ressource manuellement
az resource delete --ids <resource_id>

# Option 3: Rafraîchir l'état
terraform refresh -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

### "Error: Provider produced inconsistent result"

**Symptôme**:
```
Error: Provider produced inconsistent result after apply
```

**Solution**:
```bash
# Rafraîchir l'état
terraform refresh -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars

# Réappliquer
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

### "Error acquiring the state lock"

**Symptôme**:
```
Error locking state: Error acquiring the state lock
```

**Cause**: Une opération Terraform précédente a été interrompue.

**Solution**:
```bash
# Forcer le déverrouillage (avec précaution!)
terraform force-unlock <LOCK_ID>
```

---

## Erreurs Container Apps

### "ImagePullBackOff"

**Symptôme**: Le Container App ne démarre pas, erreur d'image.

**Causes**:
- Image non poussée vers ACR
- Mauvais nom d'image
- Credentials ACR incorrects

**Solutions**:

1. Vérifier que l'image existe dans ACR :
```bash
az acr repository list --name <acr-name>
az acr repository show-tags --name <acr-name> --repository nyc-taxi-pipeline
```

2. Pousser l'image si manquante :
```bash
az acr login --name <acr-name>
cd ../data_pipeline
.\scripts\windows\docker\build.ps1
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest
docker push <acr-url>/nyc-taxi-pipeline:latest
```

### Les logs sont vides

**Symptôme**: `az containerapp logs show` ne retourne rien.

**Causes**:
- Le container n'a pas encore démarré
- Le container a crashé immédiatement

**Solutions**:

1. Vérifier les révisions :
```bash
az containerapp revision list \
  --name ca-nyctaxi-pipeline-dev \
  --resource-group rg-nyctaxi-dev \
  --output table
```

2. Voir les événements :
```bash
az containerapp show \
  --name ca-nyctaxi-pipeline-dev \
  --resource-group rg-nyctaxi-dev \
  --query "properties.latestRevisionName"
```

---

## Erreurs PostgreSQL

### "Connection refused"

**Symptôme**:
```
psql: error: connection to server at "..." failed: Connection refused
```

**Causes**:
- Firewall bloque la connexion
- Mauvais hostname

**Solutions**:

1. Vérifier le hostname :
```bash
terraform output postgres_host
```

2. Ajouter votre IP au firewall (si connexion locale) :
```bash
# Obtenir votre IP
curl ifconfig.me

# Ajouter dans Azure Portal ou via Terraform
```

### "SSL required"

**Symptôme**:
```
SSL connection is required
```

**Solution**: Toujours utiliser `sslmode=require` :
```bash
psql "postgresql://citus:<PASSWORD>@<HOST>:5432/citus?sslmode=require"
```

---

## Commandes de diagnostic

### Docker

```bash
# État des conteneurs
docker ps -a

# Logs d'un conteneur
docker logs terraform-workspace

# Inspecter un conteneur
docker inspect terraform-workspace
```

### Azure

```bash
# Lister les ressources du Resource Group
az resource list --resource-group rg-nyctaxi-dev --output table

# État du Container App
az containerapp show \
  --name ca-nyctaxi-pipeline-dev \
  --resource-group rg-nyctaxi-dev

# Logs du Container App
az containerapp logs show \
  --name ca-nyctaxi-pipeline-dev \
  --resource-group rg-nyctaxi-dev \
  --follow
```

### Terraform

```bash
# État actuel
terraform show

# Lister les ressources gérées
terraform state list

# Détails d'une ressource
terraform state show azurerm_container_app.pipeline
```

## Besoin d'aide ?

Si le problème persiste :

1. Consultez les [logs détaillés](#commandes-de-diagnostic)
2. Vérifiez la [FAQ](./faq.md)
3. Recherchez sur Stack Overflow avec les tags `terraform`, `azure`
4. Consultez la documentation Azure officielle
