# 🎓 Guide Débutant - NYC Taxi Pipeline

Guide pas à pas pour exécuter le projet NYC Taxi Pipeline, de A à Z.

---

## 📋 Table des matières

1. [Vue d'ensemble du projet](#-vue-densemble-du-projet)
2. [Prérequis à installer](#-prérequis-à-installer)
3. [Option A : Test local (sans Azure)](#-option-a--test-local-sans-azure)
4. [Option B : Déploiement sur Azure](#-option-b--déploiement-sur-azure)
5. [Vérification des résultats](#-vérification-des-résultats)
6. [Troubleshooting](#-troubleshooting)
7. [Nettoyage](#-nettoyage)

---

## 🎯 Vue d'ensemble du projet

Ce projet analyse les données des taxis de New York. Il se compose de **2 modules** :

| Module | Rôle | Quand l'utiliser |
|--------|------|------------------|
| `data_pipeline/` | Pipeline de données Python | Télécharge, charge et transforme les données |
| `terraform_pipeline/` | Infrastructure Azure | Déploie les ressources cloud (Azure) |

### Architecture du Pipeline

```
NYC TLC (Internet)          Azure Storage / Local          PostgreSQL
     │                            │                           │
     │    Pipeline 1              │     Pipeline 2            │    Pipeline 3
     │    DOWNLOAD                │     LOAD                  │    TRANSFORM
     ▼                            ▼                           ▼
┌─────────┐               ┌─────────────┐             ┌─────────────┐
│ Fichiers│    ─────▶     │   Parquet   │   ─────▶   │   Tables    │
│ Parquet │               │   Storage   │             │ Star Schema │
└─────────┘               └─────────────┘             └─────────────┘
```

### Tables créées (Star Schema)

| Table | Type | Description |
|-------|------|-------------|
| `staging_taxi_trips` | Staging | Données brutes chargées |
| `dim_datetime` | Dimension | Dates et heures |
| `dim_location` | Dimension | Zones géographiques |
| `dim_payment` | Dimension | Types de paiement |
| `dim_vendor` | Dimension | Fournisseurs de taxi |
| `fact_trips` | Fait | Métriques des trajets |

### Volume partagé (`shared/`)

Les deux modules communiquent via un volume partagé :
- **Terraform** génère automatiquement `.env.dev`, `.env.rec`, `.env.prod`
- **Data Pipeline** lit ces fichiers pour se connecter à Azure

---

## 🔧 Prérequis à installer

### 1. Docker Desktop (obligatoire)

Docker permet d'exécuter le code dans un environnement isolé.

1. Téléchargez Docker Desktop : https://www.docker.com/products/docker-desktop/
2. Installez-le (suivez les instructions)
3. **Redémarrez votre ordinateur**
4. Lancez Docker Desktop et attendez qu'il démarre

**Vérification :**
```powershell
docker --version
# Devrait afficher: Docker version 24.x.x ou plus récent
```

### 2. Git (recommandé)

Pour cloner le projet et gérer les versions.

1. Téléchargez Git : https://git-scm.com/downloads
2. Installez avec les options par défaut

**Vérification :**
```powershell
git --version
# Devrait afficher: git version 2.x.x
```

### 3. Azure CLI (uniquement pour le mode Azure)

Si vous voulez déployer sur Azure Cloud.

1. Téléchargez : https://learn.microsoft.com/fr-fr/cli/azure/install-azure-cli-windows
2. Installez avec les options par défaut

**Vérification :**
```powershell
az --version
# Devrait afficher: azure-cli x.x.x
```

---

## 🏠 Option A : Test local (sans Azure)

**Durée estimée : 10-15 minutes**

C'est la méthode la plus simple pour tester le pipeline. Pas besoin de compte Azure !

### Étape 1 : Ouvrir PowerShell

1. Appuyez sur `Windows + X`
2. Cliquez sur "Terminal Windows" ou "PowerShell"

### Étape 2 : Naviguer vers le projet

```powershell
cd C:\Users\Utilisateur\Documents\Brief_Terraform_2
```

### Étape 3 : Aller dans le dossier data_pipeline

```powershell
cd data_pipeline
```

### Étape 4 : Construire l'image Docker

Cette commande crée l'image Docker du pipeline Python.

```powershell
.\scripts\windows\docker\build.ps1
```

**Attendez le message :** `[SUCCESS] Image construite!`

### Étape 5 : Lancer le pipeline en mode local

Cette commande lance le pipeline complet avec des émulateurs locaux :
- **Azurite** : Émule Azure Storage
- **PostgreSQL** : Base de données locale
- **Le Pipeline** : Votre code Python

```powershell
.\scripts\windows\docker\run-local.ps1
```

Un menu interactif s'affiche. Choisissez :
1. **Option 1** : Lancer le pipeline (interactif)
2. **Option 4** : Configurer la période/mode (optionnel)

### Étape 6 : Observer l'exécution

Vous allez voir dans le terminal :
1. 📥 **Pipeline 1** : Téléchargement des fichiers Parquet (~50 MB par mois)
2. 📦 **Pipeline 2** : Chargement dans PostgreSQL via DuckDB
3. 🔄 **Pipeline 3** : Création du modèle en étoile (Star Schema)

**Attendez le message :** `✅ PIPELINE TERMINÉ AVEC SUCCÈS`

### Étape 7 : Voir les données (optionnel)

Pour lancer avec l'interface graphique PgAdmin :

```powershell
.\scripts\windows\docker\run-local.ps1
# Choisir option 3: Lancer avec PgAdmin
```

Puis ouvrez http://localhost:5050 dans votre navigateur :
- **Email** : admin@local.dev
- **Mot de passe** : admin

---

## ☁️ Option B : Déploiement sur Azure

**Durée estimée : 30-45 minutes**

Cette option déploie l'infrastructure sur Azure Cloud. Nécessite un compte Azure.

### Phase 1 : Déployer l'infrastructure (15 min)

#### Étape 1 : Aller dans terraform_pipeline

```powershell
cd C:\Users\Utilisateur\Documents\Brief_Terraform_2\terraform_pipeline
```

#### Étape 2 : Configurer le mot de passe PostgreSQL

1. Ouvrez le fichier de secrets :
   ```powershell
   notepad terraform\environments\secrets.tfvars
   ```

2. Remplacez la ligne :
   ```
   postgres_admin_password = "CHANGEZ_MOI_MotDePasse123!"
   ```
   Par un vrai mot de passe sécurisé (ex: `MonMotDePasse2024!`)

3. **Sauvegardez et fermez** (Ctrl+S, puis fermez)

#### Étape 3 : Construire et lancer le workspace Terraform

```powershell
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run.ps1
```

**Vous êtes maintenant dans un conteneur Docker avec Terraform et Azure CLI.**

#### Étape 4 : Se connecter à Azure

Le script vous demande automatiquement si vous voulez vous connecter. Répondez `o` (oui).

1. Un code s'affiche (ex: `ABCD1234`)
2. Ouvrez https://microsoft.com/devicelogin dans votre navigateur
3. Collez le code et connectez-vous avec votre compte Azure

**✨ Automatisations après connexion :**
- ✅ Les providers Azure sont enregistrés automatiquement (Microsoft.App, etc.)
- ✅ `terraform init` est exécuté automatiquement

#### Étape 5 : Déployer l'infrastructure avec les commandes simplifiées

Dans le workspace, utilisez les commandes simplifiées :

```bash
# Prévisualiser les changements
plan dev

# Déployer l'environnement dev
apply dev
```

Tapez `yes` quand demandé.

**Attendez 5-10 minutes** (Cosmos DB PostgreSQL prend du temps à créer)

**✨ Génération automatique du fichier .env :**
Après `apply dev`, un fichier `shared/.env.dev` est automatiquement créé avec toutes les variables de connexion Azure.

#### Étape 6 : Sortir du conteneur

```bash
exit
```

### Phase 2 : Pousser l'image Docker vers ACR (10 min)

#### Étape 7 : Aller dans data_pipeline

```powershell
cd ..\data_pipeline
```

#### Étape 8 : Se connecter à l'ACR

Récupérez le nom de l'ACR depuis les outputs Terraform (ex: `acrnyctaxidevkbmich`) :

```powershell
az acr login --name <acr-name>
```

#### Étape 9 : Construire, tagger et pousser l'image

```powershell
.\scripts\windows\docker\build.ps1

docker tag nyc-taxi-pipeline:latest <acr-name>.azurecr.io/nyc-taxi-pipeline:latest
docker push <acr-name>.azurecr.io/nyc-taxi-pipeline:latest
```

### Phase 3 : Exécuter le pipeline sur Azure (5 min)

#### Étape 10 : Lancer le pipeline Azure

```powershell
.\scripts\windows\docker\run-azure.ps1
```

Le script détecte automatiquement le fichier `shared/.env.dev` généré par Terraform.

Choisissez :
1. **Option 1** : dev (Développement)

Le pipeline s'exécute avec les ressources Azure !

---

## ✅ Vérification des résultats

### Mode Local

#### Voir les logs du pipeline

```powershell
cd data_pipeline
.\scripts\windows\docker\logs.ps1
```

#### Se connecter à PostgreSQL

```powershell
docker exec -it docker-postgres-1 psql -U postgres -d nyctaxi
```

Puis exécutez des requêtes SQL :
```sql
-- Vérifier les tables du star schema
SELECT 'staging_taxi_trips' AS table_name, COUNT(*) FROM staging_taxi_trips
UNION ALL SELECT 'dim_datetime', COUNT(*) FROM dim_datetime
UNION ALL SELECT 'dim_location', COUNT(*) FROM dim_location
UNION ALL SELECT 'dim_payment', COUNT(*) FROM dim_payment
UNION ALL SELECT 'dim_vendor', COUNT(*) FROM dim_vendor
UNION ALL SELECT 'fact_trips', COUNT(*) FROM fact_trips;

-- Revenu moyen par trajet
SELECT AVG(montant_total) as avg_revenue FROM fact_trips;

-- Quitter
\q
```

### Mode Azure

#### Voir les logs du Container App

```powershell
az containerapp logs show --name ca-nyctaxi-pipeline-dev --resource-group fabadiRG --follow
```

#### Se connecter à PostgreSQL

```powershell
# Le hostname et mot de passe sont dans shared/.env.dev
psql "postgresql://citus:<password>@<hostname>:5432/citus?sslmode=require"
```

---

## 🔧 Troubleshooting

### Erreur : "Docker daemon is not running"

**Solution :** Lancez Docker Desktop et attendez qu'il démarre complètement.

### Erreur : "Cannot connect to the Docker daemon"

**Solution :** Redémarrez Docker Desktop ou votre ordinateur.

### Erreur : "Network timeout" lors du téléchargement

**Solution :** Vérifiez votre connexion Internet. Les fichiers Parquet font ~50 MB chacun.

### Erreur : "Image not found" sur Azure

**Solution :** Assurez-vous d'avoir poussé l'image vers ACR AVANT de lancer le pipeline Azure.

### Erreur : "MissingSubscriptionRegistration" (Microsoft.App)

**Cause :** Le provider Azure n'est pas enregistré sur votre subscription.

**Solution :** Le script l'enregistre automatiquement. Si l'erreur persiste, attendez 2-3 minutes et réessayez.

### Erreur : "Connection refused" PostgreSQL

**Causes possibles :**
1. Le firewall PostgreSQL bloque votre IP
2. Le mot de passe est incorrect

**Solution :** En dev/rec, le firewall autorise maintenant toutes les IPs. Vérifiez le mot de passe dans `shared/.env.dev`.

### Erreur : "Aucun fichier Parquet trouvé"

**Cause :** Le pipeline 1 n'a pas sauvegardé les fichiers localement.

**Solution :** Cette erreur est maintenant corrigée. Le pipeline sauvegarde les fichiers localement ET sur Azure.

### Erreur : "apply dev: command not found"

**Cause :** Les fonctions shell ne sont pas chargées.

**Solution :** Tapez `source ~/.bashrc` ou relancez le conteneur.

---

## 🗑️ Nettoyage

### Arrêter le mode local

```powershell
cd data_pipeline
.\scripts\windows\docker\stop.ps1
```

### Détruire l'infrastructure Azure

**⚠️ Attention : Cela supprime toutes les données et le fichier .env !**

```powershell
cd terraform_pipeline
.\scripts\windows\docker\run.ps1
```

Dans le conteneur :
```bash
destroy dev
```

Tapez `yes` pour confirmer.

---

## 📊 Résumé des commandes

### Mode Local (Rapide, pas d'Azure)

```powershell
cd data_pipeline
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run-local.ps1
```

### Mode Azure (Complet)

```powershell
# ============================================
# Phase 1 : Déployer l'infrastructure
# ============================================
cd terraform_pipeline
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run.ps1

# Dans le conteneur (login + init automatiques!) :
apply dev
# Attendez ~10 min (Cosmos DB est lent)
# Le fichier shared/.env.dev est généré automatiquement
exit

# ============================================
# Phase 2 : Pousser l'image Docker vers ACR
# ============================================
cd ..\data_pipeline
az acr login --name <acr-name>
.\scripts\windows\docker\build.ps1
docker tag nyc-taxi-pipeline:latest <acr-name>.azurecr.io/nyc-taxi-pipeline:latest
docker push <acr-name>.azurecr.io/nyc-taxi-pipeline:latest

# ============================================
# Phase 3 : Exécuter le pipeline Azure
# ============================================
.\scripts\windows\docker\run-azure.ps1
# Choisir environnement "dev"
```

---

## 📚 Pour aller plus loin

- [data_pipeline/README.md](./data_pipeline/README.md) - Documentation du pipeline
- [terraform_pipeline/README.md](./terraform_pipeline/README.md) - Documentation Terraform
- [brief-terraform/BRIEF.md](./brief-terraform/BRIEF.md) - Instructions originales du brief
- [ROADMAP_SHARED_ENV.md](./ROADMAP_SHARED_ENV.md) - Roadmap du volume partagé

---

**Bon courage ! 🚀**

*Si vous êtes bloqué, relisez les messages d'erreur attentivement et consultez la section Troubleshooting.*
