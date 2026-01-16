# =============================================================================
# Stop/Remove Script - Data Pipeline Docker Services (PowerShell)
# =============================================================================
# Arrete et nettoie les services Docker du pipeline
# Usage: .\stop.ps1 [-Stop] [-Volumes] [-All] [-Prune]
# =============================================================================

param(
    [switch]$Stop,
    [switch]$Volumes,
    [switch]$All,
    [switch]$Prune,
    [switch]$Help
)

# Configuration
$ImageName = "nyc-taxi-pipeline"
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
    
    # Conteneurs compose
    try {
        $containers = docker compose -f $ComposeFile ps -q 2>$null
        if ($containers) {
            $count = ($containers | Measure-Object -Line).Lines
            Write-Host "  Conteneurs compose: " -NoNewline
            Write-Host "$count actif(s)" -ForegroundColor Green
            docker compose -f $ComposeFile ps --format "table {{.Name}}\t{{.Status}}" 2>$null | Select-Object -Skip 1 | ForEach-Object {
                Write-Host "    - $_"
            }
        }
        else {
            Write-Host "  Conteneurs compose: " -NoNewline
            Write-Host "Aucun" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  Conteneurs compose: " -NoNewline
        Write-Host "Aucun" -ForegroundColor Yellow
    }
    
    # Image
    $imageExists = docker image inspect "${ImageName}:latest" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $sizeBytes = docker image inspect "${ImageName}:latest" --format '{{.Size}}' 2>$null
        $sizeMB = [math]::Round($sizeBytes / 1MB, 1)
        Write-Host "  Image pipeline: " -NoNewline
        Write-Host "${ImageName}:latest" -ForegroundColor Green -NoNewline
        Write-Host " ($sizeMB MB)"
    }
    else {
        Write-Host "  Image pipeline: " -NoNewline
        Write-Host "Non trouvee" -ForegroundColor Yellow
    }
    
    # Volumes
    $volumes = docker volume ls --filter "name=data_pipeline" -q 2>$null
    $volCount = if ($volumes) { ($volumes | Measure-Object -Line).Lines } else { 0 }
    Write-Host "  Volumes pipeline: " -NoNewline
    Write-Host "$volCount" -ForegroundColor Cyan
    
    # Volumes dangling
    $dangling = docker volume ls -f dangling=true -q 2>$null
    $dangCount = if ($dangling) { ($dangling | Measure-Object -Line).Lines } else { 0 }
    if ($dangCount -gt 0) {
        Write-Host "  Volumes orphelins: " -NoNewline
        Write-Host "$dangCount" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Show-Menu {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "         Stop/Clean - NYC Taxi Data Pipeline                   " -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Show-Status
    Write-Host "Choisissez une option :" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) " -NoNewline -ForegroundColor Green
    Write-Host "Arreter les conteneurs (garder les volumes)"
    Write-Host "  2) " -NoNewline -ForegroundColor Yellow
    Write-Host "Arreter + supprimer les volumes"
    Write-Host "  3) " -NoNewline -ForegroundColor Blue
    Write-Host "Arreter + supprimer l'image pipeline"
    Write-Host "  4) " -NoNewline -ForegroundColor Red
    Write-Host "TOUT supprimer + prune (nettoyage complet)"
    Write-Host ""
    Write-Host "  5) " -NoNewline -ForegroundColor Cyan
    Write-Host "Supprimer les volumes orphelins uniquement"
    Write-Host ""
    Write-Host "  q) " -NoNewline -ForegroundColor Red
    Write-Host "Quitter"
    Write-Host ""
}

function Stop-Containers {
    Write-Warn "Arret des conteneurs..."
    docker compose -f $ComposeFile down 2>$null
    Write-Success "Conteneurs arretes"
}

function Stop-WithVolumes {
    Write-Warn "Arret des conteneurs + suppression des volumes..."
    docker compose -f $ComposeFile down -v 2>$null
    Write-Success "Conteneurs arretes et volumes supprimes"
}

function Remove-PipelineImage {
    Write-Warn "Suppression de l'image..."
    docker rmi "${ImageName}:latest" 2>$null
    Write-Success "Image supprimee"
}

function Invoke-FullCleanup {
    Write-Host "[CLEANUP] Nettoyage complet..." -ForegroundColor Red
    
    # Arreter tout
    docker compose -f $ComposeFile down -v 2>$null
    
    # Supprimer l'image
    docker rmi "${ImageName}:latest" 2>$null
    
    # Prune images
    Write-Warn "Suppression des images inutilisees..."
    docker image prune -f
    
    # Prune volumes
    Write-Warn "Suppression des volumes orphelins..."
    docker volume prune -f
    
    Write-Success "Nettoyage complet termine"
}

function Remove-DanglingVolumes {
    $dangling = docker volume ls -f dangling=true -q 2>$null
    if ($dangling) {
        $count = ($dangling | Measure-Object -Line).Lines
        Write-Warn "Suppression de $count volume(s) orphelin(s)..."
        docker volume prune -f
        Write-Success "Volumes orphelins supprimes"
    }
    else {
        Write-Success "Aucun volume orphelin"
    }
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Aide
if ($Help) {
    Write-Host "Usage: .\stop.ps1 [-Stop] [-Volumes] [-All] [-Prune]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Stop       Arreter les conteneurs"
    Write-Host "  -Volumes    Arreter + supprimer les volumes"
    Write-Host "  -All        Arreter + supprimer volumes + image"
    Write-Host "  -Prune      Nettoyage complet (tout + prune)"
    Write-Host "  (aucun)     Affiche le menu interactif"
    exit 0
}

# Verifier Docker
if (-not (Test-DockerRunning)) {
    Write-Err "Docker n'est pas en cours d'execution!"
    exit 1
}

# Arguments CLI
if ($Stop) {
    Stop-Containers
    exit 0
}

if ($Volumes) {
    Stop-WithVolumes
    exit 0
}

if ($All) {
    Stop-WithVolumes
    Remove-PipelineImage
    exit 0
}

if ($Prune) {
    Invoke-FullCleanup
    exit 0
}

# Mode interactif
Show-Menu
$choice = Read-Host "Votre choix [1]"
if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

switch ($choice) {
    "1" { Stop-Containers }
    "2" { Stop-WithVolumes }
    "3" { Stop-WithVolumes; Remove-PipelineImage }
    "4" {
        Write-Host ""
        Write-Host "ATTENTION: Cette action supprime TOUTES les donnees!" -ForegroundColor Red
        $confirm = Read-Host "Confirmer? (tapez 'yes')"
        if ($confirm -eq "yes") {
            Invoke-FullCleanup
        }
        else {
            Write-Warn "Annule"
        }
    }
    "5" { Remove-DanglingVolumes }
    "q" { Write-Warn "Annule"; exit 0 }
    "Q" { Write-Warn "Annule"; exit 0 }
    default { Write-Err "Choix invalide"; exit 1 }
}

Write-Host ""
Write-Host "[DONE] Operation terminee" -ForegroundColor Green
