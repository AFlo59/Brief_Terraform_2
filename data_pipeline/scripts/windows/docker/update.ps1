# =============================================================================
# Update Script - Data Pipeline Docker Image (PowerShell)
# =============================================================================
# Met a jour l'image Docker du pipeline
# Usage: .\update.ps1 [-Quick] [-Full] [-Pull] [-Restart]
# =============================================================================

param(
    [switch]$Quick,
    [switch]$Full,
    [switch]$Pull,
    [switch]$Restart,
    [switch]$Help
)

# Configuration
$ImageName = "nyc-taxi-pipeline"
$ImageTag = "latest"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
$DockerDir = Join-Path $ProjectRoot "docker"
$ComposeFile = Join-Path $DockerDir "docker-compose.yml"

# Fonctions d'affichage
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Status { param($Message) Write-Host "[STATUS] $Message" -ForegroundColor Cyan }

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

function Test-DockerRunning {
    try {
        $null = docker info 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Show-Status {
    Write-Status "Etat actuel:"
    
    # Image existante ?
    $imageExists = docker image inspect "${ImageName}:${ImageTag}" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $sizeBytes = docker image inspect "${ImageName}:${ImageTag}" --format '{{.Size}}' 2>$null
        $sizeMB = [math]::Round($sizeBytes / 1MB, 1)
        $created = (docker image inspect "${ImageName}:${ImageTag}" --format '{{.Created}}' 2>$null).Substring(0, 10)
        Write-Host "  Image: " -NoNewline
        Write-Host "${ImageName}:${ImageTag}" -ForegroundColor Green -NoNewline
        Write-Host " ($sizeMB MB, creee le $created)"
    }
    else {
        Write-Host "  Image: " -NoNewline
        Write-Host "Non trouvee" -ForegroundColor Yellow
    }
    
    # Images de base
    Write-Host "  Images de base:" -ForegroundColor Cyan
    foreach ($img in @("python:3.11-slim-bookworm", "ghcr.io/astral-sh/uv:python3.11-bookworm-slim")) {
        $exists = docker image inspect $img 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] $img" -ForegroundColor Green
        }
        else {
            Write-Host "    [X] $img (non telechargee)" -ForegroundColor Yellow
        }
    }
    
    # Conteneurs en cours
    try {
        $running = docker compose -f $ComposeFile ps -q 2>$null
        if ($running) {
            $count = ($running | Measure-Object -Line).Lines
            Write-Host "  " -NoNewline
            Write-Host "[!] $count conteneur(s) actif(s) - seront redemarres" -ForegroundColor Yellow
        }
    }
    catch {}
    Write-Host ""
}

function Show-Menu {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "         Update - NYC Taxi Data Pipeline                       " -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Show-Status
    Write-Host "Choisissez une option :" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) " -NoNewline -ForegroundColor Green
    Write-Host "Quick update (avec cache)"
    Write-Host "  2) " -NoNewline -ForegroundColor Yellow
    Write-Host "Full rebuild (sans cache)"
    Write-Host "  3) " -NoNewline -ForegroundColor Blue
    Write-Host "Pull images de base + rebuild"
    Write-Host "  4) " -NoNewline -ForegroundColor Cyan
    Write-Host "Update + Relancer les services"
    Write-Host ""
    Write-Host "  q) " -NoNewline -ForegroundColor Red
    Write-Host "Quitter"
    Write-Host ""
}

function Get-BaseImages {
    Write-Info "Telechargement des images de base..."
    
    Write-Host "[1/2] python:3.11-slim-bookworm..." -ForegroundColor Cyan
    docker pull python:3.11-slim-bookworm
    
    Write-Host "[2/2] ghcr.io/astral-sh/uv:python3.11-bookworm-slim..." -ForegroundColor Cyan
    docker pull ghcr.io/astral-sh/uv:python3.11-bookworm-slim
    
    Write-Success "Images de base mises a jour"
    Write-Host ""
}

function Backup-Image {
    $exists = docker image inspect "${ImageName}:${ImageTag}" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Sauvegarde de l'image actuelle..."
        docker tag "${ImageName}:${ImageTag}" "${ImageName}:backup" 2>$null
    }
}

function Restore-Image {
    $exists = docker image inspect "${ImageName}:backup" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Warn "Restauration de l'image precedente..."
        docker tag "${ImageName}:backup" "${ImageName}:${ImageTag}"
        docker rmi "${ImageName}:backup" 2>$null
    }
}

function Remove-Backup {
    docker rmi "${ImageName}:backup" 2>$null | Out-Null
}

function Build-PipelineImage {
    param([switch]$NoCache)
    
    $buildOpts = @()
    if ($NoCache) {
        $buildOpts += "--no-cache"
        Write-Warn "Mode sans cache active"
    }
    
    Backup-Image
    
    Write-Host "[BUILD] Construction de l'image: ${ImageName}:${ImageTag}" -ForegroundColor Green
    Write-Host ""
    
    $buildArgs = @("build") + $buildOpts + @(
        "-t", "${ImageName}:${ImageTag}"
        "-f", (Join-Path $DockerDir "Dockerfile")
        $ProjectRoot
    )
    
    & docker @buildArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Success "Image mise a jour avec succes!"
        Remove-Backup
        return $true
    }
    else {
        Write-Err "Echec de la mise a jour"
        Restore-Image
        return $false
    }
}

function Restart-Services {
    try {
        $running = docker compose -f $ComposeFile ps -q 2>$null
        if ($running) {
            Write-Warn "Redemarrage des services..."
            docker compose -f $ComposeFile up -d --build
            Write-Success "Services redemarres"
        }
    }
    catch {}
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Aide
if ($Help) {
    Write-Host "Usage: .\update.ps1 [-Quick] [-Full] [-Pull] [-Restart]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Quick      Build avec cache (rapide)"
    Write-Host "  -Full       Build sans cache (complet)"
    Write-Host "  -Pull       Pull images de base + build"
    Write-Host "  -Restart    Build + redemarrer les services"
    Write-Host "  (aucun)     Affiche le menu interactif"
    exit 0
}

# Verifier Docker
if (-not (Test-DockerRunning)) {
    Write-Err "Docker n'est pas en cours d'execution!"
    exit 1
}
Write-Success "Docker est en cours d'execution"

# Arguments CLI
if ($Quick) {
    Build-PipelineImage
    exit 0
}

if ($Full) {
    Build-PipelineImage -NoCache
    exit 0
}

if ($Pull) {
    Get-BaseImages
    Build-PipelineImage
    exit 0
}

if ($Restart) {
    if (Build-PipelineImage) {
        Restart-Services
    }
    exit 0
}

# Mode interactif
Show-Menu
$choice = Read-Host "Votre choix [1]"
if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

switch ($choice) {
    "1" { Build-PipelineImage }
    "2" { Build-PipelineImage -NoCache }
    "3" { Get-BaseImages; Build-PipelineImage }
    "4" { if (Build-PipelineImage) { Restart-Services } }
    "q" { Write-Warn "Annule"; exit 0 }
    "Q" { Write-Warn "Annule"; exit 0 }
    default { Write-Err "Choix invalide"; exit 1 }
}
