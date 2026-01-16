# =============================================================================
# Run Azure Script - Data Pipeline sur ressources Azure (PowerShell)
# =============================================================================
# Utilise le fichier .env genere par Terraform
# Usage: .\run-azure.ps1 [-Env dev|rec|prod] [options]
# =============================================================================

param(
    [ValidateSet("dev", "rec", "prod")]
    [string]$Env = "dev",
    [string]$StartDate = "",
    [string]$EndDate = "",
    [string]$Mode = "",
    [switch]$Auto,
    [switch]$Help
)

# Configuration
$ImageName = "nyc-taxi-pipeline"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
$MainProject = Split-Path -Parent $ProjectRoot
$SharedDir = Join-Path $MainProject "shared"

# Fonctions d'affichage
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Run { param($Message) Write-Host "[RUN] $Message" -ForegroundColor Green }

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

function Test-EnvFile {
    param([string]$Environment)
    
    $envFile = Join-Path $SharedDir ".env.$Environment"
    
    if (-not (Test-Path $envFile)) {
        Write-Err "Fichier .env non trouve: $envFile"
        Write-Host ""
        Write-Warn "Vous devez d'abord deployer l'infrastructure avec Terraform:"
        Write-Host ""
        Write-Host "  1. Lancez le workspace Terraform:"
        Write-Host "     cd ..\terraform_pipeline"
        Write-Host "     .\scripts\windows\docker\run.ps1"
        Write-Host ""
        Write-Host "  2. Dans le workspace, deployez l'environnement:"
        Write-Host "     apply $Environment"
        Write-Host ""
        Write-Host "  Le fichier .env.$Environment sera automatiquement genere."
        return $false
    }
    return $true
}

function Show-EnvFiles {
    Write-Info "Fichiers .env disponibles:"
    
    foreach ($env in @("dev", "rec", "prod")) {
        $envFile = Join-Path $SharedDir ".env.$env"
        if (Test-Path $envFile) {
            $date = (Get-Item $envFile).LastWriteTime.ToString("yyyy-MM-dd")
            Write-Host "  " -NoNewline
            Write-Host "[OK]" -ForegroundColor Green -NoNewline
            Write-Host " .env.$env (modifie: $date)"
        }
        else {
            Write-Host "  " -NoNewline
            Write-Host "[X]" -ForegroundColor Yellow -NoNewline
            Write-Host " .env.$env (non trouve)"
        }
    }
    Write-Host ""
}

function Show-Menu {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "         Run Azure - NYC Taxi Data Pipeline                    " -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Show-EnvFiles
    Write-Host "Choisissez un environnement :" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) " -NoNewline -ForegroundColor Green
    Write-Host "dev  - Developpement"
    Write-Host "  2) " -NoNewline -ForegroundColor Yellow
    Write-Host "rec  - Recette"
    Write-Host "  3) " -NoNewline -ForegroundColor Red
    Write-Host "prod - Production"
    Write-Host ""
    Write-Host "  4) " -NoNewline -ForegroundColor Cyan
    Write-Host "Configurer les options (periode, mode)"
    Write-Host ""
    Write-Host "  q) " -NoNewline -ForegroundColor Red
    Write-Host "Quitter"
    Write-Host ""
}

function Set-Options {
    Write-Host ""
    Write-Info "Configuration du pipeline"
    Write-Host ""
    Write-Warn "Laissez vide pour utiliser les valeurs du .env"
    Write-Host ""
    
    $script:StartDate = Read-Host "Date de debut (YYYY-MM) [depuis .env]"
    $script:EndDate = Read-Host "Date de fin (YYYY-MM) [depuis .env]"
    
    Write-Host ""
    Write-Host "Modes disponibles:"
    Write-Host "  all        - Pipeline complet"
    Write-Host "  download   - Telechargement uniquement"
    Write-Host "  load       - Chargement uniquement"
    Write-Host "  transform  - Transformation uniquement"
    $script:Mode = Read-Host "Mode [depuis .env]"
    
    Write-Host ""
    Write-Success "Options configurees"
}

function Start-AzurePipeline {
    param([string]$Environment)
    
    $envFile = Join-Path $SharedDir ".env.$Environment"
    
    # Verifier le fichier .env
    if (-not (Test-EnvFile $Environment)) {
        exit 1
    }
    
    Write-Run "Demarrage du pipeline Azure ($Environment)..."
    Write-Host ""
    
    # Construire les arguments docker
    $dockerArgs = @("run", "--rm", "-it", "--env-file", $envFile)
    
    # Overrides optionnels
    if (-not [string]::IsNullOrEmpty($StartDate)) {
        $dockerArgs += @("-e", "START_DATE=$StartDate")
        Write-Host "  - Start Date: $StartDate (override)"
    }
    
    if (-not [string]::IsNullOrEmpty($EndDate)) {
        $dockerArgs += @("-e", "END_DATE=$EndDate")
        Write-Host "  - End Date: $EndDate (override)"
    }
    
    if (-not [string]::IsNullOrEmpty($Mode)) {
        $dockerArgs += @("-e", "PIPELINE_MODE=$Mode")
        Write-Host "  - Mode: $Mode (override)"
    }
    
    # Forcer USE_LOCAL=false pour Azure
    $dockerArgs += @("-e", "USE_LOCAL=false")
    
    $dockerArgs += "${ImageName}:latest"
    
    Write-Host ""
    
    # Executer
    & docker @dockerArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Success "Pipeline termine!"
    }
    else {
        Write-Err "Le pipeline a echoue"
        exit 1
    }
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Aide
if ($Help) {
    Write-Host "Usage: .\run-azure.ps1 [-Env ENV] [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Env ENV         Environnement: dev, rec, prod (defaut: dev)"
    Write-Host "  -StartDate       Date de debut (override .env)"
    Write-Host "  -EndDate         Date de fin (override .env)"
    Write-Host "  -Mode            Mode: download, load, transform, all"
    Write-Host "  -Auto            Lancer sans menu interactif"
    Write-Host "  -Help            Afficher cette aide"
    exit 0
}

# Verifier Docker
if (-not (Test-DockerRunning)) {
    Write-Err "Docker n'est pas en cours d'execution!"
    Write-Info "Lancez Docker Desktop et reessayez."
    exit 1
}

# Verifier image
$imageExists = docker image inspect "${ImageName}:latest" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Image non trouvee. Construction..."
    & "$ScriptDir\build.ps1" -Auto
}

# Mode automatique
if ($Auto) {
    Start-AzurePipeline $Env
    exit 0
}

# Mode interactif
Show-Menu
$choice = Read-Host "Votre choix [1]"
if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

switch ($choice) {
    "1" { Start-AzurePipeline "dev" }
    "2" { Start-AzurePipeline "rec" }
    "3" { Start-AzurePipeline "prod" }
    "4" {
        Set-Options
        Show-Menu
        $choice2 = Read-Host "Votre choix [1]"
        if ([string]::IsNullOrEmpty($choice2)) { $choice2 = "1" }
        switch ($choice2) {
            "1" { Start-AzurePipeline "dev" }
            "2" { Start-AzurePipeline "rec" }
            "3" { Start-AzurePipeline "prod" }
            default { Write-Warn "Annule" }
        }
    }
    "q" { Write-Warn "Annule"; exit 0 }
    "Q" { Write-Warn "Annule"; exit 0 }
    default { Write-Err "Choix invalide"; exit 1 }
}
