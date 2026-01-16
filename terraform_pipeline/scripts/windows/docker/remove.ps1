# =============================================================================
# Remove Script - Terraform Docker Resources (PowerShell)
# =============================================================================
# Supprime les conteneurs, images et volumes Docker du workspace Terraform
# Usage: .\remove.ps1 [-All] [-Container] [-Image] [-Volumes] [-Prune] [-Help]
# =============================================================================

param(
    [switch]$All,
    [switch]$Container,
    [switch]$Image,
    [switch]$Volumes,
    [switch]$Prune,
    [switch]$Help
)

# Configuration
$ImageName = "terraform-azure-workspace"
$ImageTag = "latest"
$ContainerName = "terraform-workspace"

# =============================================================================
# Fonctions d'affichage
# =============================================================================

function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Ok { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Remove { param($Message) Write-Host "[REMOVE] $Message" -ForegroundColor Yellow }
function Write-Stop { param($Message) Write-Host "[STOP] $Message" -ForegroundColor Yellow }

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

function Show-Status {
    Write-Host ""
    Write-Host "Etat actuel:" -ForegroundColor Cyan
    
    # Conteneur en cours
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
    
    # Image principale
    $mainImage = docker image inspect "${ImageName}:${ImageTag}" 2>$null
    if ($mainImage) {
        $sizeBytes = (docker image inspect "${ImageName}:${ImageTag}" --format '{{.Size}}' 2>$null)
        $sizeMB = [math]::Round($sizeBytes / 1MB, 1)
        Write-Host "  " -NoNewline
        Write-Host "[Exists]" -ForegroundColor Green -NoNewline
        Write-Host " Image: ${ImageName}:${ImageTag} (${sizeMB} MB)"
    }
    else {
        Write-Host "  " -NoNewline
        Write-Host "[None]" -ForegroundColor Red -NoNewline
        Write-Host " Image: ${ImageName}:${ImageTag} (n'existe pas)"
    }
    
    # Image backup
    $backupImage = docker image inspect "${ImageName}:backup" 2>$null
    if ($backupImage) {
        Write-Host "  " -NoNewline
        Write-Host "[Exists]" -ForegroundColor Yellow -NoNewline
        Write-Host " Image backup: ${ImageName}:backup"
    }
    
    # Volumes orphelins
    $danglingVolumes = (docker volume ls -qf dangling=true 2>$null | Measure-Object).Count
    if ($danglingVolumes -gt 0) {
        Write-Host "  " -NoNewline
        Write-Host "[Warning]" -ForegroundColor Yellow -NoNewline
        Write-Host " Volumes orphelins: $danglingVolumes"
    }
    
    # Images orphelines
    $danglingImages = (docker images -qf dangling=true 2>$null | Measure-Object).Count
    if ($danglingImages -gt 0) {
        Write-Host "  " -NoNewline
        Write-Host "[Warning]" -ForegroundColor Yellow -NoNewline
        Write-Host " Images orphelines: $danglingImages"
    }
    
    Write-Host ""
}

function Show-Menu {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "         Nettoyage - Terraform Azure Workspace                  " -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Que voulez-vous supprimer ?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) Conteneur uniquement (garde l'image pour rebuild rapide)" -ForegroundColor Green
    Write-Host "  2) Conteneur + Image (nettoyage complet du projet)" -ForegroundColor Yellow
    Write-Host "  3) TOUT + Prune (conteneur, image, volumes orphelins, cache)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  4) Supprimer uniquement les volumes orphelins" -ForegroundColor Cyan
    Write-Host "  5) Supprimer uniquement les images orphelines (dangling)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  q) Quitter sans rien faire" -ForegroundColor Red
    Write-Host ""
}

function Remove-TerraformContainer {
    Write-Host ""
    
    # Arreter si en cours
    $runningContainer = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    if ($runningContainer) {
        Write-Stop "Arret du conteneur: $ContainerName"
        docker stop $ContainerName 2>$null | Out-Null
    }
    
    # Supprimer
    $existingContainer = docker ps -a --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    if ($existingContainer) {
        Write-Remove "Suppression du conteneur: $ContainerName"
        docker rm $ContainerName 2>$null | Out-Null
        Write-Ok "Conteneur supprime"
    }
    else {
        Write-Info "Aucun conteneur a supprimer"
    }
}

function Remove-TerraformImage {
    # Image principale
    $mainImage = docker image inspect "${ImageName}:${ImageTag}" 2>$null
    if ($mainImage) {
        Write-Remove "Suppression de l'image: ${ImageName}:${ImageTag}"
        docker rmi "${ImageName}:${ImageTag}" 2>$null | Out-Null
        Write-Ok "Image supprimee"
    }
    else {
        Write-Info "Image principale n'existe pas"
    }
    
    # Image backup
    $backupImage = docker image inspect "${ImageName}:backup" 2>$null
    if ($backupImage) {
        Write-Remove "Suppression de l'image backup"
        docker rmi "${ImageName}:backup" 2>$null | Out-Null
        Write-Ok "Image backup supprimee"
    }
}

function Remove-DanglingVolumes {
    $volumes = docker volume ls -qf dangling=true 2>$null
    if ($volumes) {
        Write-Remove "Suppression des volumes orphelins..."
        docker volume prune -f 2>$null | Out-Null
        Write-Ok "Volumes orphelins supprimes"
    }
    else {
        Write-Info "Aucun volume orphelin"
    }
}

function Remove-DanglingImages {
    $images = docker images -qf dangling=true 2>$null
    if ($images) {
        Write-Remove "Suppression des images orphelines..."
        docker image prune -f 2>$null | Out-Null
        Write-Ok "Images orphelines supprimees"
    }
    else {
        Write-Info "Aucune image orpheline"
    }
}

function Invoke-FullPrune {
    Write-Host ""
    Write-Host "[PRUNE] Nettoyage complet Docker..." -ForegroundColor Red
    docker system prune -f 2>$null | Out-Null
    Write-Ok "Cache Docker nettoye"
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Aide
if ($Help) {
    Write-Host "Usage: .\remove.ps1 [option]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Container  Supprimer uniquement le conteneur"
    Write-Host "  -Image      Supprimer conteneur + image"
    Write-Host "  -Volumes    Supprimer les volumes orphelins"
    Write-Host "  -All        Supprimer tout (conteneur, image, volumes)"
    Write-Host "  -Prune      Supprimer tout + prune Docker"
    Write-Host "  -Help       Afficher cette aide"
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
if ($Prune) {
    Show-Status
    Remove-TerraformContainer
    Remove-TerraformImage
    Invoke-FullPrune
    Write-Host ""
    Write-Success "Prune complet termine!"
    exit 0
}

if ($All) {
    Show-Status
    Remove-TerraformContainer
    Remove-TerraformImage
    Remove-DanglingVolumes
    Remove-DanglingImages
    Write-Host ""
    Write-Success "Nettoyage complet termine!"
    exit 0
}

if ($Image) {
    Remove-TerraformContainer
    Remove-TerraformImage
    Write-Host ""
    Write-Success "Image supprimee!"
    exit 0
}

if ($Container) {
    Remove-TerraformContainer
    Write-Host ""
    Write-Success "Conteneur supprime!"
    exit 0
}

if ($Volumes) {
    Remove-DanglingVolumes
    Write-Host ""
    Write-Success "Volumes nettoyes!"
    exit 0
}

# 3. Mode interactif
Show-Status
Show-Menu

$choice = Read-Host "Votre choix [1]"
if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

switch ($choice) {
    "1" {
        Remove-TerraformContainer
        Write-Host ""
        Write-Success "Conteneur supprime! L'image est conservee pour un rebuild rapide."
    }
    "2" {
        Remove-TerraformContainer
        Remove-TerraformImage
        Write-Host ""
        Write-Success "Conteneur et image supprimes!"
    }
    "3" {
        Write-Host ""
        Write-Warn "Ceci va supprimer le conteneur, l'image ET nettoyer le cache Docker."
        $confirm = Read-Host "Confirmer? (o/n) [n]"
        if ($confirm -match "^[oOyY]$") {
            Remove-TerraformContainer
            Remove-TerraformImage
            Remove-DanglingVolumes
            Remove-DanglingImages
            Invoke-FullPrune
            Write-Host ""
            Write-Success "Nettoyage complet termine!"
        }
        else {
            Write-Warn "Operation annulee"
        }
    }
    "4" {
        Remove-DanglingVolumes
        Write-Host ""
        Write-Success "Volumes orphelins supprimes!"
    }
    "5" {
        Remove-DanglingImages
        Write-Host ""
        Write-Success "Images orphelines supprimees!"
    }
    "q" {
        Write-Info "Aucune action effectuee"
        exit 0
    }
    "Q" {
        Write-Info "Aucune action effectuee"
        exit 0
    }
    default {
        Write-Err "Choix invalide"
        exit 1
    }
}
