# Shared Directory

Ce dossier contient les fichiers `.env` générés automatiquement par Terraform.

## Fichiers générés

| Fichier | Description |
|---------|-------------|
| `.env.dev` | Variables d'environnement pour DEV |
| `.env.rec` | Variables d'environnement pour REC |
| `.env.prod` | Variables d'environnement pour PROD |

## Usage

Ces fichiers sont :
- **Générés** par `terraform apply` dans le conteneur `terraform_pipeline`
- **Consommés** par le conteneur `data_pipeline`
- **Supprimés** par `terraform destroy`

## Sécurité

⚠️ **Ces fichiers contiennent des secrets et ne doivent JAMAIS être commités !**

Ils sont automatiquement ignorés par `.gitignore`.
