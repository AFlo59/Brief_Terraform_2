# 🌍 Gestion des Environnements

## Vue d'ensemble

Le projet supporte 3 environnements avec des configurations adaptées :

| Environnement | Fichier | Usage |
|---------------|---------|-------|
| **dev** 🟢 | `environments/dev.tfvars` | Développement, tests locaux |
| **rec** 🟡 | `environments/rec.tfvars` | Recette, staging, pré-production |
| **prod** 🔴 | `environments/prod.tfvars` | Production |

## Structure des fichiers

```
terraform/environments/
├── dev.tfvars              # Configuration dev (versionné)
├── rec.tfvars              # Configuration rec (versionné)
├── prod.tfvars             # Configuration prod (versionné)
├── secrets.tfvars          # 🔐 Secrets (NON versionné)
└── secrets.tfvars.example  # Template pour secrets
```

## Comparaison des environnements

### Ressources

| Ressource | Dev 🟢 | Rec 🟡 | Prod 🔴 |
|-----------|--------|--------|---------|
| **ACR SKU** | Basic | Standard | Premium |
| **PostgreSQL vCores** | 1 | 2 | 4 |
| **PostgreSQL Storage** | 32 GB | 64 GB | 128 GB |
| **Container CPU** | 0.5 | 1.0 | 2.0 |
| **Container Memory** | 1 Gi | 2 Gi | 4 Gi |
| **Min Replicas** | 0 | 0 | 1 |
| **Max Replicas** | 1 | 2 | 5 |
| **Storage Replication** | LRS | LRS | GRS |
| **Log Retention** | 30j | 60j | 90j |

### Données Pipeline

| Paramètre | Dev 🟢 | Rec 🟡 | Prod 🔴 |
|-----------|--------|--------|---------|
| **Start Date** | 2024-01 | 2024-01 | 2023-01 |
| **End Date** | 2024-02 | 2024-06 | 2024-12 |
| **Volume** | 2 mois | 6 mois | 1 an |

### Coûts estimés

| Environnement | Coût mensuel (24/7) | Coût avec destroy quotidien |
|---------------|---------------------|----------------------------|
| **Dev** 🟢 | ~60-80€ | ~15-20€ |
| **Rec** 🟡 | ~100-150€ | ~30-40€ |
| **Prod** 🔴 | ~200-300€ | N/A (toujours actif) |

## Configuration des secrets

### Créer le fichier de secrets

```bash
cp environments/secrets.tfvars.example environments/secrets.tfvars
```

### Contenu du fichier

```hcl
# environments/secrets.tfvars
postgres_admin_password = "VotreMotDePasseSecurise123!"
```

### Exigences du mot de passe

- Minimum 8 caractères
- Au moins une majuscule
- Au moins un chiffre
- Au moins un caractère spécial

> ⚠️ **IMPORTANT**: Ne jamais commiter `secrets.tfvars` dans Git !

## Déploiement par environnement

### Avec les scripts

```powershell
# Windows - Déployer en dev
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action apply

# Windows - Déployer en rec
.\scripts\windows\terraform\deploy.ps1 -Env rec -Action apply

# Windows - Déployer en prod
.\scripts\windows\terraform\deploy.ps1 -Env prod -Action apply
```

```bash
# Linux - Équivalent
./scripts/linux/terraform/deploy.sh dev apply
./scripts/linux/terraform/deploy.sh rec apply
./scripts/linux/terraform/deploy.sh prod apply
```

### Manuellement

```bash
# Dev
terraform apply \
  -var-file=environments/dev.tfvars \
  -var-file=environments/secrets.tfvars

# Rec
terraform apply \
  -var-file=environments/rec.tfvars \
  -var-file=environments/secrets.tfvars

# Prod
terraform apply \
  -var-file=environments/prod.tfvars \
  -var-file=environments/secrets.tfvars
```

## Nommage des ressources

Les ressources sont nommées selon le pattern :

```
{type}-{project}-{environment}
```

| Environnement | Resource Group | Storage | ACR | Container App |
|---------------|---------------|---------|-----|---------------|
| dev | rg-nyctaxi-dev | stnyctaxi{random} | acrnyctaxi{random} | ca-nyctaxi-pipeline-dev |
| rec | rg-nyctaxi-rec | stnyctaxi{random} | acrnyctaxi{random} | ca-nyctaxi-pipeline-rec |
| prod | rg-nyctaxi-prod | stnyctaxi{random} | acrnyctaxi{random} | ca-nyctaxi-pipeline-prod |

> Note: Storage Account et ACR partagent le même suffixe aléatoire pour l'unicité globale.

## Isolation des environnements

Chaque environnement est **complètement isolé** :

- Resource Groups séparés
- Storage Accounts séparés
- Bases de données séparées
- Container Apps séparés

Cela permet de :
- Tester sans impacter la production
- Détruire un environnement sans affecter les autres
- Appliquer des politiques différentes par environnement

## Bonnes pratiques

### Développement

```bash
# Démarrer la journée
terraform apply -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars

# Fin de journée - ÉCONOMISER !
terraform destroy -var-file=environments/dev.tfvars -var-file=environments/secrets.tfvars
```

### Production

- **Ne jamais** faire `terraform destroy` sans validation
- Utiliser des alertes de coûts Azure
- Configurer des backups PostgreSQL
- Monitorer les logs via Log Analytics

## Variables personnalisées

### Modifier une variable pour un environnement

Éditez le fichier `.tfvars` correspondant :

```hcl
# environments/dev.tfvars

# Augmenter les ressources pour tests de charge
container_app_cpu    = 1.0
container_app_memory = "2Gi"

# Plus de données
pipeline_start_date = "2024-01"
pipeline_end_date   = "2024-06"
```

### Ajouter une nouvelle variable

1. Déclarez dans `variables.tf` :
```hcl
variable "my_new_var" {
  description = "Ma nouvelle variable"
  type        = string
  default     = "valeur_par_defaut"
}
```

2. Ajoutez dans chaque `*.tfvars` si nécessaire :
```hcl
my_new_var = "valeur_specifique"
```
