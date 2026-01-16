# 📜 Documentation des Scripts

## Structure

```
scripts/
├── windows/                 # 🪟 PowerShell (Windows)
│   ├── docker/              # Gestion Docker
│   │   ├── build.ps1
│   │   ├── run.ps1
│   │   ├── update.ps1
│   │   └── remove.ps1
│   └── terraform/           # Gestion Terraform
│       ├── deploy.ps1
│       └── check-prereqs.ps1
└── linux/                   # 🐧 Bash (WSL/Linux)
    ├── docker/
    │   ├── build.sh
    │   ├── run.sh
    │   ├── update.sh
    │   └── remove.sh
    └── terraform/
        ├── deploy.sh
        └── check-prereqs.sh
```

---

## Scripts Docker

### build.ps1 / build.sh

**Description**: Construit l'image Docker contenant Terraform et Azure CLI.

**Usage**:
```powershell
# Windows
.\scripts\windows\docker\build.ps1 [-NoCache]
```

```bash
# Linux
./scripts/linux/docker/build.sh [--no-cache]
```

**Options**:
| Option | Description |
|--------|-------------|
| `-NoCache` / `--no-cache` | Reconstruit sans utiliser le cache Docker |

**Exemple**:
```powershell
# Build standard
.\scripts\windows\docker\build.ps1

# Build sans cache (après modification du Dockerfile)
.\scripts\windows\docker\build.ps1 -NoCache
```

---

### run.ps1 / run.sh

**Description**: Lance le conteneur Terraform en mode interactif.

**Usage**:
```powershell
# Windows
.\scripts\windows\docker\run.ps1 [-Detach] [-Cmd "commande"] [-Help]
```

```bash
# Linux
./scripts/linux/docker/run.sh [--detach|-d] [--cmd|-c "commande"] [--help|-h]
```

**Options**:
| Option | Description |
|--------|-------------|
| `-Detach` / `--detach` | Lance le conteneur en arrière-plan |
| `-Cmd` / `--cmd` | Exécute une commande spécifique |
| `-Help` / `--help` | Affiche l'aide |

**Exemples**:
```powershell
# Mode interactif (défaut)
.\scripts\windows\docker\run.ps1

# Exécuter une commande
.\scripts\windows\docker\run.ps1 -Cmd "terraform plan"

# En arrière-plan
.\scripts\windows\docker\run.ps1 -Detach
```

**Volumes montés**:
- `/workspace/terraform` → Configs Terraform (lecture/écriture)
- `/workspace/data_pipeline` → Pipeline de données (lecture seule)

---

### update.ps1 / update.sh

**Description**: Met à jour l'image Docker (rebuild sans cache).

**Usage**:
```powershell
# Windows
.\scripts\windows\docker\update.ps1
```

```bash
# Linux
./scripts/linux/docker/update.sh
```

**Comportement**:
1. Arrête le conteneur existant
2. Sauvegarde l'ancienne image
3. Reconstruit sans cache
4. Supprime l'ancienne image si succès
5. Restaure si échec

---

### remove.ps1 / remove.sh

**Description**: Supprime les conteneurs et/ou images Docker.

**Usage**:
```powershell
# Windows
.\scripts\windows\docker\remove.ps1 [-All] [-Image] [-Container] [-Help]
```

```bash
# Linux
./scripts/linux/docker/remove.sh [--all|-a] [--image|-i] [--container|-c] [--help|-h]
```

**Options**:
| Option | Description |
|--------|-------------|
| `-All` / `--all` | Supprime tout (défaut) |
| `-Image` / `--image` | Supprime uniquement l'image |
| `-Container` / `--container` | Supprime uniquement le conteneur |

**Exemples**:
```powershell
# Supprimer tout
.\scripts\windows\docker\remove.ps1

# Supprimer uniquement le conteneur
.\scripts\windows\docker\remove.ps1 -Container
```

---

## Scripts Terraform

### deploy.ps1 / deploy.sh

**Description**: Déploie l'infrastructure vers un environnement spécifique.

**Usage**:
```powershell
# Windows
.\scripts\windows\terraform\deploy.ps1 -Env <env> [-Action <action>] [-Help]
```

```bash
# Linux
./scripts/linux/terraform/deploy.sh <env> [action]
```

**Paramètres**:
| Paramètre | Valeurs | Description |
|-----------|---------|-------------|
| `Env` | `dev`, `rec`, `prod` | Environnement cible |
| `Action` | `plan`, `apply`, `destroy` | Action Terraform (défaut: plan) |

**Exemples**:
```powershell
# Prévisualiser en dev
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action plan

# Déployer en dev
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action apply

# Déployer en recette
.\scripts\windows\terraform\deploy.ps1 -Env rec -Action apply

# Détruire l'environnement dev
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action destroy
```

```bash
# Linux équivalent
./scripts/linux/terraform/deploy.sh dev plan
./scripts/linux/terraform/deploy.sh dev apply
./scripts/linux/terraform/deploy.sh rec apply
./scripts/linux/terraform/deploy.sh dev destroy
```

**Sécurité**:
- Demande confirmation pour `destroy` en production
- Tapez `DESTROY PROD` pour confirmer

---

### check-prereqs.ps1 / check-prereqs.sh

**Description**: Vérifie que tous les prérequis sont installés.

**Usage**:
```powershell
# Windows
.\scripts\windows\terraform\check-prereqs.ps1
```

```bash
# Linux
./scripts/linux/terraform/check-prereqs.sh
```

**Vérifie**:
- ✅ Docker installé et en cours d'exécution
- ✅ Azure CLI installé et connecté
- ✅ Fichiers d'environnement présents
- ✅ Fichier secrets.tfvars configuré
- ✅ Fichiers Terraform présents
- ✅ Image Docker construite

**Sortie**:
```
================================================================
    Vérification des prérequis - NYC Taxi Pipeline
================================================================

Docker:
[OK]    Docker Engine (v24.0.7)
[OK]    Docker Running

Azure CLI:
[OK]    Azure CLI (v2.55.0)
[OK]    Azure Login (Ma Souscription)

Configuration:
[OK]    environments/dev.tfvars
[OK]    environments/rec.tfvars
[OK]    environments/prod.tfvars
[WARN]  secrets.tfvars - Mot de passe par défaut détecté!

Fichiers Terraform:
[OK]    main.tf
[OK]    variables.tf
[OK]    outputs.tf
[OK]    providers.tf

================================================================
  Tous les prérequis sont satisfaits!
================================================================
```

---

## Résumé des commandes

### Windows (PowerShell)

```powershell
# Docker
.\scripts\windows\docker\build.ps1           # Construire
.\scripts\windows\docker\run.ps1             # Lancer interactif
.\scripts\windows\docker\run.ps1 -Cmd "cmd"  # Exécuter commande
.\scripts\windows\docker\update.ps1          # Mettre à jour
.\scripts\windows\docker\remove.ps1          # Supprimer

# Terraform
.\scripts\windows\terraform\check-prereqs.ps1            # Vérifier
.\scripts\windows\terraform\deploy.ps1 -Env dev          # Plan dev
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action apply   # Apply dev
.\scripts\windows\terraform\deploy.ps1 -Env dev -Action destroy # Destroy dev
```

### Linux / WSL (Bash)

```bash
# Docker
./scripts/linux/docker/build.sh              # Construire
./scripts/linux/docker/run.sh                # Lancer interactif
./scripts/linux/docker/run.sh --cmd "cmd"    # Exécuter commande
./scripts/linux/docker/update.sh             # Mettre à jour
./scripts/linux/docker/remove.sh             # Supprimer

# Terraform
./scripts/linux/terraform/check-prereqs.sh   # Vérifier
./scripts/linux/terraform/deploy.sh dev      # Plan dev
./scripts/linux/terraform/deploy.sh dev apply   # Apply dev
./scripts/linux/terraform/deploy.sh dev destroy # Destroy dev
```
