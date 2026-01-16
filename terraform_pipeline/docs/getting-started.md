# 🚀 Getting Started

Guide de démarrage rapide pour déployer l'infrastructure NYC Taxi Pipeline.

## Prérequis

### Logiciels requis

| Outil | Version | Téléchargement |
|-------|---------|----------------|
| Docker Desktop | Latest | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Azure CLI | >= 2.50 | [docs.microsoft.com](https://docs.microsoft.com/cli/azure/install-azure-cli) |
| Git | Latest | [git-scm.com](https://git-scm.com/) |

### Compte Azure

- Souscription Azure active
- Droits de création de ressources (Contributor ou Owner)

## Workflow simplifié

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   build.ps1  │────▶ │    run.ps1   │────▶│  apply dev   │
│  (image)     │      │  (workspace) │      │ (déploie +   │
└──────────────┘      └──────────────┘      │ génère .env) │
                                            └──────────────┘
```

## Étapes d'installation

### Étape 1 : Configurer les secrets

```powershell
# Éditer le fichier de secrets
cd terraform_pipeline
notepad terraform\environments\secrets.tfvars
```

Définissez un mot de passe PostgreSQL sécurisé :
```hcl
postgres_admin_password = "VotreMotDePasseSecurise123!"
```

> ⚠️ Le mot de passe doit contenir au moins 8 caractères avec majuscules, chiffres et symboles.

### Étape 2 : Construire l'image Docker

```powershell
# Windows
.\scripts\windows\docker\build.ps1
```

```bash
# Linux/WSL
./scripts/linux/docker/build.sh
```

### Étape 3 : Lancer le workspace Terraform

```powershell
# Windows
.\scripts\windows\docker\run.ps1
```

```bash
# Linux/WSL
./scripts/linux/docker/run.sh
```

### Étape 4 : Se connecter à Azure

Le script propose automatiquement la connexion :

```
Voulez-vous vous connecter maintenant? (o/n) o
```

1. Répondez `o`
2. Un code s'affiche (ex: `ABCD1234`)
3. Ouvrez https://microsoft.com/devicelogin dans votre navigateur
4. Entrez le code et connectez-vous

**Automatisations après connexion :**
- ✅ Providers Azure enregistrés automatiquement
- ✅ `terraform init` exécuté automatiquement

### Étape 5 : Déployer l'infrastructure

Utilisez les **commandes simplifiées** :

```bash
# Prévisualiser les changements
plan dev

# Déployer l'environnement dev
apply dev
```

**Après `apply dev` :**
- ✅ Infrastructure Azure créée (~10 min)
- ✅ Fichier `shared/.env.dev` généré automatiquement

### Étape 6 : Push de l'image du pipeline

**Sortez du conteneur** (`exit`) puis :

```powershell
# Dans le dossier data_pipeline
cd ..\data_pipeline

# Récupérer le nom ACR depuis les outputs Terraform
# (affiché à la fin de apply dev)

# Se connecter à ACR
az acr login --name <acr-name>

# Builder l'image
.\scripts\windows\docker\build.ps1

# Tagger et pousser
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest
docker push <acr-url>/nyc-taxi-pipeline:latest
```

### Étape 7 : Exécuter le pipeline

```powershell
# Le fichier shared/.env.dev est automatiquement détecté
.\scripts\windows\docker\run-azure.ps1
```

## Commandes dans le workspace

### Commandes simplifiées (recommandé)

| Commande | Description |
|----------|-------------|
| `plan dev` | Prévisualiser les changements |
| `apply dev` | Déployer + générer `.env.dev` |
| `destroy dev` | Détruire + supprimer `.env.dev` |
| `genenv dev` | Régénérer `.env.dev` sans apply |

### Autres commandes utiles

```bash
terraform output              # Voir les outputs
az login --use-device-code    # Se reconnecter
exit                          # Quitter le workspace
```

## Vérification

### Voir les outputs Terraform

```bash
terraform output
```

### Vérifier le fichier .env généré

```bash
cat /workspace/shared/.env.dev
```

### Se connecter à PostgreSQL

```bash
# Les credentials sont dans shared/.env.dev
psql "postgresql://citus:<PASSWORD>@<HOSTNAME>:5432/citus?sslmode=require"
```

## Nettoyage

```bash
# Détruire l'infrastructure (supprime aussi shared/.env.dev)
destroy dev
```

## Volume partagé

Le fichier `.env` généré est accessible par `data_pipeline` :

```
Brief_Terraform_2/
├── shared/
│   └── .env.dev    # Généré ici
├── terraform_pipeline/
│   └── (génère .env)
└── data_pipeline/
    └── (utilise .env)
```

## Prochaines étapes

- 📖 [Configuration des environnements](./environments.md)
- 🏗️ [Architecture déployée](./architecture.md)
- 🔧 [Documentation des scripts](./scripts.md)
- 🐛 [Troubleshooting](./troubleshooting.md)
