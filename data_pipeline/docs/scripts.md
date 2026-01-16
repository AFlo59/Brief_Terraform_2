# 📜 Documentation des Scripts

## Structure

```
scripts/
├── windows/docker/          # PowerShell (Windows)
│   ├── build.ps1            # Construire l'image
│   ├── run-local.ps1        # Lancer en local
│   ├── run-azure.ps1        # Lancer sur Azure
│   ├── stop.ps1             # Arrêter les services
│   └── logs.ps1             # Voir les logs
└── linux/docker/            # Bash (WSL/Linux)
    ├── build.sh
    ├── run-local.sh
    ├── run-azure.sh
    ├── stop.sh
    └── logs.sh
```

## Scripts disponibles

### build.ps1 / build.sh

Construit l'image Docker du pipeline.

```powershell
# Windows
.\scripts\windows\docker\build.ps1 [-NoCache]
```

```bash
# Linux
./scripts/linux/docker/build.sh [--no-cache]
```

---

### run-local.ps1 / run-local.sh

Lance le pipeline avec émulateurs locaux.

```powershell
# Windows
.\scripts\windows\docker\run-local.ps1 `
  [-StartDate "2024-01"] `
  [-EndDate "2024-02"] `
  [-Mode "all"] `
  [-Detach] `
  [-WithTools]
```

```bash
# Linux
./scripts/linux/docker/run-local.sh \
  --start-date "2024-01" \
  --end-date "2024-02" \
  --mode "all" \
  --detach \
  --with-tools
```

**Options:**

| Option | Description |
|--------|-------------|
| `StartDate` | Date de début (YYYY-MM) |
| `EndDate` | Date de fin (YYYY-MM) |
| `Mode` | download, load, transform, all |
| `Detach` | Lancer en arrière-plan |
| `WithTools` | Inclure PgAdmin |

---

### run-azure.ps1 / run-azure.sh

Lance le pipeline sur ressources Azure.

```powershell
# Windows
.\scripts\windows\docker\run-azure.ps1 `
  -Env "dev" `
  [-StartDate "2024-01"] `
  [-EndDate "2024-03"] `
  [-Mode "all"]
```

```bash
# Linux
./scripts/linux/docker/run-azure.sh \
  --env "dev" \
  --start-date "2024-01" \
  --end-date "2024-03" \
  --mode "all"
```

**Options:**

| Option | Description |
|--------|-------------|
| `Env` | **Requis**: dev, rec, prod |
| `StartDate` | Date de début |
| `EndDate` | Date de fin |
| `Mode` | download, load, transform, all |

---

### stop.ps1 / stop.sh

Arrête les services Docker.

```powershell
# Windows
.\scripts\windows\docker\stop.ps1 [-Clean]
```

```bash
# Linux
./scripts/linux/docker/stop.sh [--clean]
```

**Options:**

| Option | Description |
|--------|-------------|
| `Clean` | Supprimer aussi les volumes (données) |

---

### logs.ps1 / logs.sh

Affiche les logs des services.

```powershell
# Windows
.\scripts\windows\docker\logs.ps1 `
  [-Service "pipeline"] `
  [-Follow] `
  [-Lines 100]
```

```bash
# Linux
./scripts/linux/docker/logs.sh \
  --service "pipeline" \
  --follow \
  --lines 100
```

**Options:**

| Option | Description |
|--------|-------------|
| `Service` | pipeline, postgres, azurite, pgadmin, all |
| `Follow` | Suivre en temps réel |
| `Lines` | Nombre de lignes |

## Résumé des commandes

### Windows

```powershell
# Construire
.\scripts\windows\docker\build.ps1

# Lancer en local
.\scripts\windows\docker\run-local.ps1 -StartDate "2024-01" -EndDate "2024-01"

# Lancer sur Azure
.\scripts\windows\docker\run-azure.ps1 -Env dev

# Voir les logs
.\scripts\windows\docker\logs.ps1 -Follow

# Arrêter
.\scripts\windows\docker\stop.ps1
```

### Linux

```bash
# Construire
./scripts/linux/docker/build.sh

# Lancer en local
./scripts/linux/docker/run-local.sh --start-date "2024-01" --end-date "2024-01"

# Lancer sur Azure
./scripts/linux/docker/run-azure.sh --env dev

# Voir les logs
./scripts/linux/docker/logs.sh --follow

# Arrêter
./scripts/linux/docker/stop.sh
```
