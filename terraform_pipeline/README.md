# 🚀 Terraform Pipeline - NYC Taxi Infrastructure

Infrastructure as Code pour le projet NYC Taxi Pipeline sur Azure.

## 📋 Vue d'ensemble

Ce dossier contient:
- **docker/** : Image Docker avec Terraform + Azure CLI
- **scripts/** : Scripts organisés par plateforme (Windows/Linux)
- **terraform/** : Configuration Terraform pour Azure

## 🏗️ Architecture déployée

```
┌──────────────────────────────────────────────────────────────────┐
│                        AZURE CLOUD                               │
│                                                                  │
│  ┌──────────────┐     ┌──────────────────┐     ┌──────────────┐  │
│  │   Storage    │     │  Container Apps  │     │  Cosmos DB   │  │
│  │   Account    │───▶ │   Environment    │───▶│  PostgreSQL  │  │
│  │  raw/proc    │     │   + Pipeline App │     │   (Citus)    │  │
│  └──────────────┘     └──────────────────┘     └──────────────┘  │
│                              │                                   │
│  ┌──────────────┐     ┌──────┴───────┐                           │
│  │  Container   │     │     Log      │                           │
│  │  Registry    │     │   Analytics  │                           │
│  └──────────────┘     └──────────────┘                           │
└──────────────────────────────────────────────────────────────────┘
```

## 🎯 Fonctionnalités clés

### Volume partagé avec Data Pipeline

Après `terraform apply`, un fichier `.env` est **automatiquement généré** dans `shared/` :

```
shared/
├── .env.dev    ← Généré par "apply dev"
├── .env.rec    ← Généré par "apply rec"
└── .env.prod   ← Généré par "apply prod"
```

Ce fichier contient toutes les variables de connexion Azure pour `data_pipeline`.

### Commandes simplifiées

Dans le workspace Terraform, utilisez ces commandes :

| Commande | Description |
|----------|-------------|
| `plan dev` | Prévisualiser les changements (dev) |
| `apply dev` | Déployer + générer `.env.dev` |
| `destroy dev` | Détruire + supprimer `.env.dev` |
| `genenv dev` | Régénérer le fichier `.env.dev` |

## 🚀 Démarrage rapide

### 1. Construire l'image Docker

```powershell
# Windows (PowerShell)
.\scripts\windows\docker\build.ps1
```

```bash
# Linux / WSL
./scripts/linux/docker/build.sh
```

### 2. Lancer le workspace Terraform interactif

```powershell
# Windows
.\scripts\windows\docker\run.ps1
```

```bash
# Linux
./scripts/linux/docker/run.sh
```

### 3. Dans le conteneur : Se connecter et déployer

```bash
# Le script propose automatiquement la connexion Azure
# Répondez "o" pour vous connecter

# Après connexion, les providers sont enregistrés et terraform init exécuté

# Déployer l'environnement dev
apply dev

# Attendre ~10 min (Cosmos DB est long)
# Le fichier shared/.env.dev est généré automatiquement !
```

### 4. Quitter et utiliser le fichier .env

```bash
exit

# Le fichier shared/.env.dev est prêt pour data_pipeline
```

## 📁 Structure des fichiers

```
terraform_pipeline/
├── docker/
│   ├── Dockerfile           # Image Terraform + Azure CLI
│   └── entrypoint.sh        # Script d'initialisation
├── scripts/
│   ├── windows/docker/      # Scripts PowerShell
│   │   ├── build.ps1        # Construire l'image
│   │   ├── run.ps1          # Lancer le workspace
│   │   ├── update.ps1       # Mettre à jour l'image
│   │   └── remove.ps1       # Supprimer les ressources
│   └── linux/docker/        # Scripts Bash
├── terraform/
│   ├── providers.tf         # Configuration des providers
│   ├── variables.tf         # Définition des variables
│   ├── main.tf              # Ressources Azure principales
│   ├── outputs.tf           # Outputs après déploiement
│   ├── modules/             # Modules Terraform
│   │   └── storage/         # Module Storage Account
│   ├── scripts/             # Scripts de génération .env
│   │   ├── apply.sh         # Wrapper terraform apply + genenv
│   │   ├── destroy.sh       # Wrapper terraform destroy
│   │   └── generate-env.sh  # Génère le fichier .env
│   └── environments/        # Configs par environnement
│       ├── dev.tfvars       # Développement
│       ├── rec.tfvars       # Recette
│       ├── prod.tfvars      # Production
│       └── secrets.tfvars   # Secrets (gitignore)
└── docs/                    # Documentation
```

## 📝 Configuration

### Environnements

| Environnement | Fichier | Usage |
|---------------|---------|-------|
| **dev** | `environments/dev.tfvars` | Développement, ressources minimales |
| **rec** | `environments/rec.tfvars` | Recette/Staging |
| **prod** | `environments/prod.tfvars` | Production |

### Configuration des secrets

```bash
# Le fichier secrets.tfvars contient le mot de passe PostgreSQL
# Modifiez-le avant le premier déploiement
notepad terraform\environments\secrets.tfvars
```

### Différences entre environnements

| Ressource | Dev | Rec | Prod |
|-----------|-----|-----|------|
| ACR SKU | Basic | Standard | Premium |
| PostgreSQL vCores | 1 | 2 | 4 |
| PostgreSQL Storage | 32 GB | 64 GB | 128 GB |
| Container CPU | 0.5 | 1.0 | 2.0 |
| Container Memory | 1 Gi | 2 Gi | 4 Gi |
| Firewall AllowAllIPs | ✅ Oui | ✅ Oui | ❌ Non |
| Min Replicas | 0 | 0 | 1 |

### Firewall PostgreSQL

En **dev** et **rec**, le firewall autorise toutes les IPs (sécurisé par mot de passe + SSL).
En **prod**, seuls les services Azure sont autorisés.

## 🔧 Commandes dans le workspace

### Commandes simplifiées (recommandé)

```bash
plan dev      # terraform plan pour dev
apply dev     # terraform apply + génère shared/.env.dev
destroy dev   # terraform destroy + supprime shared/.env.dev
genenv dev    # Régénère shared/.env.dev sans apply
```

### Commandes Terraform complètes

```bash
# Plan
terraform plan -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars

# Destroy
terraform destroy -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

### Autres commandes utiles

```bash
terraform output                    # Voir tous les outputs
terraform output postgres_password  # Voir un output spécifique
az login --use-device-code          # Se reconnecter à Azure
exit                                # Quitter le workspace
```

## 🔄 Workflow complet

### Phase 1 : Déployer l'infrastructure

```bash
# Dans le conteneur Terraform
apply dev
# Attendez ~10 min
# Le fichier shared/.env.dev est créé automatiquement
exit
```

### Phase 2 : Push de l'image Docker

```bash
# Depuis data_pipeline/
az acr login --name <acr-name>
./scripts/linux/docker/build.sh
docker tag nyc-taxi-pipeline:latest <acr-url>/nyc-taxi-pipeline:latest
docker push <acr-url>/nyc-taxi-pipeline:latest
```

### Phase 3 : Exécuter le pipeline

```bash
# Le fichier shared/.env.dev est automatiquement détecté
./scripts/linux/docker/run-azure.sh
```

## ⚠️ Points d'attention

1. **Ordre d'exécution**:
   - `terraform apply` crée l'infrastructure + génère `.env`
   - L'image Docker doit être poussée vers ACR
   - Puis le pipeline peut s'exécuter

2. **Authentification Azure**:
   - Le script d'entrée propose automatiquement la connexion
   - Utilisez `az login --use-device-code` dans le conteneur

3. **Secrets**:
   - Ne commitez jamais `secrets.tfvars`
   - Les fichiers `shared/.env.*` sont aussi dans `.gitignore`

4. **Cosmos DB**:
   - Utilise `BurstableMemoryOptimized` pour 1 vCore
   - Le nom inclut un suffixe aléatoire pour unicité globale

## 🐛 Troubleshooting

### "apply dev: command not found"

**Solution :** Tapez `source ~/.bashrc` ou relancez le conteneur.

### "Connection refused" PostgreSQL

**Vérifications :**
- En dev/rec, le firewall autorise toutes les IPs
- Vérifiez le mot de passe dans `shared/.env.dev`

### "Image not found" Container App

**Solution :** Poussez l'image vers ACR avant que Container Apps ne démarre.

### Terraform state lock

**Solution :**
```bash
terraform force-unlock <LOCK_ID>
```

## 🗑️ Nettoyage

```bash
# Détruire l'infrastructure Azure (supprime aussi shared/.env.dev)
destroy dev

# Supprimer les ressources Docker locales
exit
.\scripts\windows\docker\remove.ps1
```

## 📚 Documentation

- [Getting Started](./docs/getting-started.md)
- [Architecture](./docs/architecture.md)
- [Environments](./docs/environments.md)
- [Terraform](./docs/terraform.md)
- [Troubleshooting](./docs/troubleshooting.md)

## 🔗 Liens

- [Data Pipeline](../data_pipeline/) - Pipeline de données
- [Guide Débutant](../GUIDE_DEBUTANT.md) - Guide pas à pas
- [Brief](../brief-terraform/BRIEF.md) - Instructions originales
