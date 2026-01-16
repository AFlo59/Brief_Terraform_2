# =============================================================================
# Build Script - Terraform Docker Image (PowerShell)
# =============================================================================
# Construit ou récupère l'image Docker pour le workspace Terraform
# Usage: .\build.ps1 [-NoCache] [-Pull] [-Auto]
# =============================================================================

param(
    [switch]$NoCache,
    [switch]$Pull,
    [switch]$Auto,
    [switch]$Help
)

# Configuration
$ImageName = "terraform-azure-workspace"
$ImageTag = "latest"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
$DockerDir = Join-Path $ProjectRoot "docker"

# Fonctions d'affichage
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Check { param($Message) Write-Host "[CHECK] $Message" -ForegroundColor Cyan }
function Write-Ok { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }

# Afficher l'aide
if ($Help) {
    Write-Host "Usage: .\build.ps1 [-NoCache] [-Pull] [-Auto]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Auto      Build avec cache (par defaut)"
    Write-Host "  -NoCache   Build sans cache (reconstruction complete)"
    Write-Host "  -Pull      Pull images de base + build"
    Write-Host "  (aucun)    Affiche le menu interactif"
    exit 0
}

# Fonction pour vérifier que Docker tourne
function Test-DockerRunning {
    try {
        $null = docker info 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Fonction pour vérifier la connexion Docker (test réel)
function Test-DockerConnection {
    try {
        # Essaie de pull une petite image pour tester
        $null = docker pull --quiet hello-world 2>$null
        if ($LASTEXITCODE -eq 0) {
            # Nettoyer
            $null = docker rmi hello-world 2>$null
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Fonction pour le docker login
function Invoke-DockerLogin {
    Write-Warn "Connexion a Docker Hub requise..."
    Write-Info "Creez un compte gratuit sur https://hub.docker.com si necessaire"
    Write-Host ""
    
    & docker login
    
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Echec de la connexion a Docker Hub"
        return $false
    }
    
    Write-Ok "Connecte a Docker Hub"
    return $true
}

# Fonction pour vérifier et réparer les credentials Docker
function Ensure-DockerCredentials {
    Write-Check "Verification de la connexion Docker..."
    
    if (-not (Test-DockerConnection)) {
        Write-Warn "Impossible de se connecter a Docker Hub"
        Write-Host ""
        
        $loginChoice = Read-Host "Voulez-vous vous connecter a Docker Hub? (o/n) [o]"
        if ([string]::IsNullOrEmpty($loginChoice)) { $loginChoice = "o" }
        
        if ($loginChoice -match "^[oOyY]$") {
            # Supprimer le fichier config corrompu si présent
            $dockerConfigPath = Join-Path $env:USERPROFILE ".docker\config.json"
            if (Test-Path $dockerConfigPath) {
                Write-Info "Reinitialisation de la configuration Docker..."
                Remove-Item -Path $dockerConfigPath -Force -ErrorAction SilentlyContinue
            }
            
            $loginResult = Invoke-DockerLogin
            if (-not $loginResult) {
                exit 1
            }
        }
        else {
            Write-Err "Connexion Docker requise pour telecharger les images de base"
            exit 1
        }
    }
    else {
        Write-Ok "Connexion Docker fonctionnelle"
    }
    Write-Host ""
}

# Fonction pour afficher le menu
function Show-Menu {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "         Build - Terraform Azure Workspace                      " -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Choisissez une option :" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) Build avec cache (rapide si deja construit)" -ForegroundColor Green
    Write-Host "  2) Build sans cache (reconstruction complete)" -ForegroundColor Yellow
    Write-Host "  3) Mettre a jour les images de base + build" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  q) Quitter" -ForegroundColor Red
    Write-Host ""
}

# Fonction pour s'assurer que l'image de base est disponible
function Ensure-BaseImage {
    Write-Info "Verification de l'image de base Terraform..."
    
    # Toujours pull l'image de base pour éviter les erreurs de credentials BuildKit
    & docker pull hashicorp/terraform:1.7.0
    
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Impossible de telecharger l'image de base"
        Write-Info "Essayez: docker login"
        exit 1
    }
    Write-Ok "Image de base prete"
    Write-Host ""
}

# Fonction pour construire l'image
function Build-Image {
    param([bool]$UseNoCache = $false)
    
    $BuildOpts = @()
    if ($UseNoCache) {
        $BuildOpts += "--no-cache"
        Write-Warn "Mode sans cache active"
    }
    
    # Vérification du Dockerfile
    $DockerfilePath = Join-Path $DockerDir "Dockerfile"
    if (-not (Test-Path $DockerfilePath)) {
        Write-Err "Dockerfile non trouve: $DockerfilePath"
        exit 1
    }
    
    # S'assurer que l'image de base est disponible
    Ensure-BaseImage
    
    Write-Info "Construction de l'image: ${ImageName}:${ImageTag}"
    Write-Info "Contexte de build: $DockerDir"
    Write-Host ""
    
    try {
        $buildArgs = @("build") + $BuildOpts + @(
            "-t", "${ImageName}:${ImageTag}"
            "-f", $DockerfilePath
            $DockerDir
        )
        
        & docker @buildArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Success "Image construite avec succes!"
            Show-NextSteps
        }
        else {
            Write-Err "Echec de la construction de l'image"
            exit 1
        }
    }
    catch {
        Write-Err "Erreur lors de la construction: $_"
        exit 1
    }
}

# Fonction pour pull les images de base et build
function Pull-AndBuild {
    Write-Info "Telechargement des images de base..."
    
    & docker pull hashicorp/terraform:1.7.0
    
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Image de base telechargee"
        Write-Host ""
        Write-Info "Construction de l'image locale..."
        Build-Image -UseNoCache $false
    }
    else {
        Write-Err "Echec du telechargement"
        exit 1
    }
}

# Fonction pour afficher les prochaines étapes
function Show-NextSteps {
    Write-Host ""
    Write-Host "Prochaines etapes :" -ForegroundColor Cyan
    Write-Host "  .\scripts\windows\docker\run.ps1"
    Write-Host ""
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# 1. Vérifier que Docker tourne
if (-not (Test-DockerRunning)) {
    Write-Err "Docker n'est pas en cours d'execution!"
    Write-Info "Lancez Docker Desktop et reessayez."
    exit 1
}

# 2. Vérifier/réparer les credentials Docker (AVANT tout build)
Ensure-DockerCredentials

# 3. Traitement des arguments en ligne de commande
if ($NoCache) {
    Build-Image -UseNoCache $true
    exit 0
}

if ($Pull) {
    Pull-AndBuild
    exit 0
}

if ($Auto) {
    Build-Image -UseNoCache $false
    exit 0
}

# 4. Mode interactif si pas d'arguments
Show-Menu
$choice = Read-Host "Votre choix [1]"
if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

switch ($choice) {
    "1" {
        Build-Image -UseNoCache $false
    }
    "2" {
        Build-Image -UseNoCache $true
    }
    "3" {
        Pull-AndBuild
    }
    "q" {
        Write-Warn "Annule"
        exit 0
    }
    "Q" {
        Write-Warn "Annule"
        exit 0
    }
    default {
        Write-Err "Choix invalide"
        exit 1
    }
}
