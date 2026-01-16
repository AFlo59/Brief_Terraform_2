# 📚 Documentation - Terraform Pipeline

Bienvenue dans la documentation du projet NYC Taxi Pipeline Infrastructure.

## 📖 Table des matières

| Document | Description |
|----------|-------------|
| [Architecture](./architecture.md) | Vue d'ensemble de l'infrastructure Azure |
| [Getting Started](./getting-started.md) | Guide de démarrage rapide |
| [Workflow](./workflow.md) | Ordre d'utilisation terraform_pipeline + data_pipeline |
| [Sync Brief](./sync-brief.md) | Conformité avec le BRIEF.md |
| [Scripts](./scripts.md) | Documentation des scripts disponibles |
| [Environments](./environments.md) | Gestion des environnements (dev/rec/prod) |
| [Terraform](./terraform.md) | Configuration et ressources Terraform |
| [Troubleshooting](./troubleshooting.md) | Résolution des problèmes courants |
| [FAQ](./faq.md) | Questions fréquentes |

## 🎯 Fonctionnalités clés

### Volume partagé

Le projet génère automatiquement des fichiers `.env` pour `data_pipeline` :

```
Brief_Terraform_2/
├── shared/                  # Volume partagé
│   ├── .env.dev            # Généré par "apply dev"
│   ├── .env.rec            # Généré par "apply rec"
│   └── .env.prod           # Généré par "apply prod"
├── terraform_pipeline/      # Génère les .env
└── data_pipeline/           # Utilise les .env
```

### Commandes simplifiées

Dans le workspace Terraform :

| Commande | Description |
|----------|-------------|
| `plan dev` | Prévisualiser les changements |
| `apply dev` | Déployer + générer `.env.dev` |
| `destroy dev` | Détruire + supprimer `.env.dev` |
| `genenv dev` | Régénérer `.env.dev` |

## 🚀 Démarrage rapide

```powershell
# 1. Configurer le mot de passe PostgreSQL
notepad terraform\environments\secrets.tfvars

# 2. Construire et lancer le workspace
.\scripts\windows\docker\build.ps1
.\scripts\windows\docker\run.ps1

# 3. Dans le conteneur (login automatique proposé)
apply dev

# 4. Le fichier shared/.env.dev est généré !
```

## 📁 Structure du projet

```
terraform_pipeline/
├── docs/               # 📚 Documentation
├── docker/             # 🐳 Image Docker Terraform
│   ├── Dockerfile      # Terraform + Azure CLI
│   └── entrypoint.sh   # Initialisation + commandes simplifiées
├── scripts/            # 📜 Scripts par plateforme
│   ├── windows/        # PowerShell
│   └── linux/          # Bash
└── terraform/          # ⚙️ Configuration Terraform
    ├── main.tf         # Ressources principales
    ├── outputs.tf      # Outputs (utilisés pour .env)
    ├── variables.tf    # Variables
    ├── modules/        # Modules réutilisables
    ├── scripts/        # Scripts de génération .env
    │   ├── apply.sh    # Wrapper apply + genenv
    │   ├── destroy.sh  # Wrapper destroy
    │   └── generate-env.sh  # Génère le .env
    └── environments/   # Configs par environnement
        ├── dev.tfvars
        ├── rec.tfvars
        ├── prod.tfvars
        └── secrets.tfvars
```

## 🏗️ Infrastructure déployée

| Ressource | Description |
|-----------|-------------|
| Storage Account | Blob containers `raw` et `processed` |
| Container Registry | Registry pour l'image du pipeline |
| Cosmos DB PostgreSQL | Base de données (Citus) |
| Log Analytics | Monitoring et logs |
| Container Apps | Environnement + App pour le pipeline |

## 🔗 Ressources externes

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Cosmos DB for PostgreSQL](https://learn.microsoft.com/en-us/azure/cosmos-db/postgresql/)
- [Data Pipeline](../../data_pipeline/README.md)
- [Guide Débutant](../../GUIDE_DEBUTANT.md)
