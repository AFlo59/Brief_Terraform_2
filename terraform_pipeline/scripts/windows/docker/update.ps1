# =============================================================================
# Update Script - Terraform Docker Image (PowerShell)
# =============================================================================
# Met a jour l'image Docker avec plusieurs options
# Usage: .\update.ps1 [-Quick] [-Full] [-Pull] [-Auto] [-Help]
# =============================================================================

param(
    [switch]$Quick,
    [switch]$Full,
    [switch]$Pull,
    [switch]$Auto,
    [switch]$Help
)

# Configuration
$ImageName = "terraform-azure-workspace"
$ImageTag = "latest"
$ContainerName = "terraform-workspace"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# =============================================================================
# Fonctions d'affichage
# =============================================================================

function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Ok { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Update { param($Message) Write-Host "[UPDATE] $Message" -ForegroundColor Green }
function Write-Stop { param($Message) Write-Host "[STOP] $Message" -ForegroundColor Yellow }
function Write-Backup { param($Message) Write-Host "[BACKUP] $Message" -ForegroundColor Cyan }
function Write-Restore { param($Message) Write-Host "[RESTORE] $Message" -ForegroundColor Red }

# =============================================================================
# Fonctions utilitaires
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

function Show-CurrentStatus {
    Write-Host ""
    Write-Host "Etat actuel:" -ForegroundColor Cyan
    
    # Conteneur
    $runningContainer = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    $stoppedContainer = docker ps -a --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    
    if ($runningContainer) {
        Write-Host "  " -NoNewline
        Write-Host "[Running]" -ForegroundColor Green -NoNewline
        Write-Host " Conteneur: $ContainerName (en cours d'execution)"
    }
    elseif ($stoppedContainer) {
        Write-Host "  " -NoNewline
        Write-Host "[Stopped]" -ForegroundColor Yellow -NoNewline
        Write-Host " Conteneur: $ContainerName (arrete)"
    }
    else {
        Write-Host "  " -NoNewline
        Write-Host "[None]" -ForegroundColor Red -NoNewline
        Write-Host " Conteneur: $ContainerName (n'existe pas)"
    }
    
    # Image
    $mainImage = docker image inspect "${ImageName}:${ImageTag}" 2>$null
    if ($mainImage) {
        $sizeBytes = (docker image inspect "${ImageName}:${ImageTag}" --format '{{.Size}}' 2>$null)
        $sizeMB = [math]::Round($sizeBytes / 1MB, 1)
        $created = (docker image inspect "${ImageName}:${ImageTag}" --format '{{.Created}}' 2>$null)
        if ($created) {
            $createdDate = $created.Split('T')[0]
        } else {
            $createdDate = "inconnue"
        }
        
        Write-Host "  " -NoNewline
        Write-Host "[Exists]" -ForegroundColor Green -NoNewline
        Write-Host " Image: ${ImageName}:${ImageTag}"
        Write-Host "      Taille: ${sizeMB} MB"
        Write-Host "      Creee le: $createdDate"
    }
    else {
        Write-Host "  " -NoNewline
        Write-Host "[None]" -ForegroundColor Red -NoNewline
        Write-Host " Image: ${ImageName}:${ImageTag} (n'existe pas)"
    }
    
    # Image de base
    $baseImage = docker image inspect "hashicorp/terraform:1.7.0" 2>$null
    if ($baseImage) {
        Write-Host "  " -NoNewline
        Write-Host "[Exists]" -ForegroundColor Green -NoNewline
        Write-Host " Image de base: hashicorp/terraform:1.7.0 (presente)"
    }
    else {
        Write-Host "  " -NoNewline
        Write-Host "[None]" -ForegroundColor Yellow -NoNewline
        Write-Host " Image de base: hashicorp/terraform:1.7.0 (a telecharger)"
    }
    
    Write-Host ""
}

function Show-Menu {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "         Mise a jour - Terraform Azure Workspace                " -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Choisissez le type de mise a jour:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) Mise a jour rapide (avec cache Docker)" -ForegroundColor Green
    Write-Host "     -> Rapide si seuls quelques fichiers ont change"
    Write-Host ""
    Write-Host "  2) Mise a jour complete (sans cache)" -ForegroundColor Yellow
    Write-Host "     -> Reconstruit tout depuis zero"
    Write-Host ""
    Write-Host "  3) Mise a jour + Pull images de base" -ForegroundColor Blue
    Write-Host "     -> Telecharge les dernieres versions des images de base"
    Write-Host ""
    Write-Host "  4) Mise a jour + Lancer le conteneur" -ForegroundColor Cyan
    Write-Host "     -> Met a jour puis demarre automatiquement"
    Write-Host ""
    Write-Host "  q) Quitter" -ForegroundColor Red
    Write-Host ""
}

function Stop-TerraformContainer {
    $runningContainer = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    if ($runningContainer) {
        Write-Stop "Arret du conteneur en cours..."
        docker stop $ContainerName 2>$null | Out-Null
    }
    
    $existingContainer = docker ps -a --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    if ($existingContainer) {
        Write-Host "[REMOVE] Suppression du conteneur..." -ForegroundColor Yellow
        docker rm $ContainerName 2>$null | Out-Null
    }
}

function Backup-Image {
    $existingImage = docker image inspect "${ImageName}:${ImageTag}" 2>$null
    if ($existingImage) {
        Write-Backup "Sauvegarde de l'image actuelle..."
        docker tag "${ImageName}:${ImageTag}" "${ImageName}:backup" 2>$null
    }
}

function Remove-BackupImage {
    $backupImage = docker image inspect "${ImageName}:backup" 2>$null
    if ($backupImage) {
        Write-Host "[CLEANUP] Suppression de l'ancienne image..." -ForegroundColor Cyan
        docker rmi "${ImageName}:backup" 2>$null | Out-Null
    }
}

function Restore-BackupImage {
    $backupImage = docker image inspect "${ImageName}:backup" 2>$null
    if ($backupImage) {
        Write-Restore "Restauration de l'ancienne image..."
        docker tag "${ImageName}:backup" "${ImageName}:${ImageTag}"
        Write-Ok "Ancienne image restauree"
    }
}

function Invoke-Update {
    param(
        [string]$BuildOption,
        [bool]$StartAfter = $false
    )
    
    Write-Host ""
    Stop-TerraformContainer
    Backup-Image
    
    Write-Host "[BUILD] Reconstruction de l'image..." -ForegroundColor Green
    Write-Host ""
    
    try {
        # Build selon l'option
        switch ($BuildOption) {
            "quick" { & "$ScriptDir\build.ps1" -Auto }
            "full" { & "$ScriptDir\build.ps1" -NoCache }
            "pull" { & "$ScriptDir\build.ps1" -Pull }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Remove-BackupImage
            Write-Host ""
            Write-Success "Image mise a jour avec succes!"
            
            if ($StartAfter) {
                Write-Host ""
                Write-Info "Demarrage du conteneur..."
                & "$ScriptDir\run.ps1"
            }
            else {
                Write-Host ""
                Write-Host "Prochaine etape:" -ForegroundColor Cyan
                Write-Host "  .\scripts\windows\docker\run.ps1"
            }
        }
        else {
            throw "Build failed"
        }
    }
    catch {
        Write-Host ""
        Write-Err "Echec de la mise a jour!"
        Restore-BackupImage
        exit 1
    }
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Aide
if ($Help) {
    Write-Host "Usage: .\update.ps1 [option]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Quick   Mise a jour rapide (avec cache)"
    Write-Host "  -Full    Mise a jour complete (sans cache)"
    Write-Host "  -Pull    Mise a jour + pull images de base"
    Write-Host "  -Auto    Mise a jour + lancer conteneur"
    Write-Host "  -Help    Afficher cette aide"
    Write-Host ""
    Write-Host "Sans option: menu interactif"
    exit 0
}

# 1. Verifier Docker
if (-not (Test-DockerRunning)) {
    Write-Err "Docker n'est pas en cours d'execution!"
    Write-Info "Lancez Docker Desktop et reessayez."
    exit 1
}
Write-Ok "Docker est en cours d'execution"

# 2. Traitement des arguments CLI
if ($Quick) {
    Show-CurrentStatus
    Invoke-Update -BuildOption "quick" -StartAfter $false
    exit 0
}

if ($Full) {
    Show-CurrentStatus
    Invoke-Update -BuildOption "full" -StartAfter $false
    exit 0
}

if ($Pull) {
    Show-CurrentStatus
    Invoke-Update -BuildOption "pull" -StartAfter $false
    exit 0
}

if ($Auto) {
    Show-CurrentStatus
    Invoke-Update -BuildOption "quick" -StartAfter $true
    exit 0
}

# 3. Mode interactif
Show-CurrentStatus
Show-Menu

$choice = Read-Host "Votre choix [1]"
if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

switch ($choice) {
    "1" {
        Invoke-Update -BuildOption "quick" -StartAfter $false
    }
    "2" {
        Invoke-Update -BuildOption "full" -StartAfter $false
    }
    "3" {
        Invoke-Update -BuildOption "pull" -StartAfter $false
    }
    "4" {
        Invoke-Update -BuildOption "quick" -StartAfter $true
    }
    "q" {
        Write-Info "Mise a jour annulee"
        exit 0
    }
    "Q" {
        Write-Info "Mise a jour annulee"
        exit 0
    }
    default {
        Write-Err "Choix invalide"
        exit 1
    }
}
