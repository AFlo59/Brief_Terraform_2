# =============================================================================
# Run Local Script - Data Pipeline avec emulateurs locaux (PowerShell)
# =============================================================================
# Lance le pipeline en mode local avec PostgreSQL et Azurite
# Usage: .\run-local.ps1 [options]
# =============================================================================

param(
    [string]$StartDate = "2024-01",
    [string]$EndDate = "2024-01",
    [string]$Mode = "all",
    [switch]$Detach,
    [switch]$WithTools,
    [switch]$Auto,
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

function Test-Image {
    $imageExists = docker image inspect "${ImageName}:latest" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Image non trouvee. Construction..."
        & "$ScriptDir\build.ps1" -Auto
    }
}

function Show-Status {
    Write-Info "Services actuels:"
    
    try {
        $containers = docker compose -f $ComposeFile ps -q 2>$null
        if ($containers) {
            $count = ($containers | Measure-Object -Line).Lines
            Write-Host "  " -NoNewline
            Write-Host "$count service(s) actif(s)" -ForegroundColor Green
            docker compose -f $ComposeFile ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>$null | Select-Object -Skip 1 | ForEach-Object {
                Write-Host "    $_"
            }
        }
        else {
            Write-Host "  " -NoNewline
            Write-Host "Aucun service actif" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  " -NoNewline
        Write-Host "Aucun service actif" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-Menu {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "         Run Local - NYC Taxi Data Pipeline                    " -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Show-Status
    Write-Host "Configuration actuelle:" -ForegroundColor Cyan
    Write-Host "  - Periode: $StartDate -> $EndDate"
    Write-Host "  - Mode: $Mode"
    Write-Host ""
    Write-Host "Choisissez une option :" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) " -NoNewline -ForegroundColor Green
    Write-Host "Lancer le pipeline (interactif)"
    Write-Host "  2) " -NoNewline -ForegroundColor Blue
    Write-Host "Lancer en arriere-plan"
    Write-Host "  3) " -NoNewline -ForegroundColor Cyan
    Write-Host "Lancer avec PgAdmin (outil DB)"
    Write-Host "  4) " -NoNewline -ForegroundColor Yellow
    Write-Host "Configurer la periode/mode"
    Write-Host ""
    Write-Host "  q) " -NoNewline -ForegroundColor Red
    Write-Host "Quitter"
    Write-Host ""
}

function Set-Configuration {
    Write-Host ""
    Write-Info "Configuration du pipeline"
    Write-Host ""
    
    $input = Read-Host "Date de debut (YYYY-MM) [$StartDate]"
    if (-not [string]::IsNullOrEmpty($input)) { $script:StartDate = $input }
    
    $input = Read-Host "Date de fin (YYYY-MM) [$EndDate]"
    if (-not [string]::IsNullOrEmpty($input)) { $script:EndDate = $input }
    
    Write-Host ""
    Write-Host "Modes disponibles:"
    Write-Host "  all        - Pipeline complet (download -> load -> transform)"
    Write-Host "  download   - Telechargement uniquement"
    Write-Host "  load       - Chargement uniquement"
    Write-Host "  transform  - Transformation uniquement"
    $input = Read-Host "Mode [$Mode]"
    if (-not [string]::IsNullOrEmpty($input)) { $script:Mode = $input }
    
    Write-Host ""
    Write-Success "Configuration mise a jour"
    Write-Host "  - Periode: $StartDate -> $EndDate"
    Write-Host "  - Mode: $Mode"
    Write-Host ""
}

function Start-Pipeline {
    param(
        [switch]$Background,
        [switch]$Tools
    )
    
    # Variables d'environnement
    $env:START_DATE = $StartDate
    $env:END_DATE = $EndDate
    $env:PIPELINE_MODE = $Mode
    $env:USE_LOCAL = "true"
    
    # Options compose
    $composeArgs = @("-f", $ComposeFile)
    
    if ($Tools) {
        $composeArgs += @("--profile", "tools")
        Write-Info "PgAdmin sera accessible sur http://localhost:5050"
        Write-Host "  - Email: admin@local.dev"
        Write-Host "  - Password: admin"
        Write-Host ""
    }
    
    Write-Run "Demarrage du pipeline..."
    Write-Host "  - Periode: $StartDate -> $EndDate"
    Write-Host "  - Mode: $Mode"
    Write-Host ""
    
    if ($Background) {
        $composeArgs += @("up", "-d", "--build")
        & docker compose @composeArgs
        
        Write-Host ""
        Write-Success "Pipeline lance en arriere-plan!"
        Write-Host ""
        Write-Info "Commandes utiles:"
        Write-Host "  .\scripts\windows\docker\logs.ps1    - Voir les logs"
        Write-Host "  .\scripts\windows\docker\stop.ps1    - Arreter"
        Write-Host ""
    }
    else {
        $composeArgs += @("up", "--build")
        & docker compose @composeArgs
    }
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Aide
if ($Help) {
    Write-Host "Usage: .\run-local.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -StartDate DATE   Date de debut (YYYY-MM), defaut: 2024-01"
    Write-Host "  -EndDate DATE     Date de fin (YYYY-MM), defaut: 2024-01"
    Write-Host "  -Mode MODE        Mode: download, load, transform, all (defaut)"
    Write-Host "  -Detach           Lancer en arriere-plan"
    Write-Host "  -WithTools        Inclure PgAdmin"
    Write-Host "  -Auto             Lancer sans menu interactif"
    Write-Host "  -Help             Afficher cette aide"
    exit 0
}

# Verifier Docker
if (-not (Test-DockerRunning)) {
    Write-Err "Docker n'est pas en cours d'execution!"
    Write-Info "Lancez Docker Desktop et reessayez."
    exit 1
}
Write-Success "Docker est en cours d'execution"

# Verifier image
Test-Image

# Mode automatique ou avec options
if ($Auto -or $Detach -or $WithTools) {
    Start-Pipeline -Background:$Detach -Tools:$WithTools
    exit 0
}

# Mode interactif
Show-Menu
$choice = Read-Host "Votre choix [1]"
if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

switch ($choice) {
    "1" { Start-Pipeline }
    "2" { Start-Pipeline -Background }
    "3" { Start-Pipeline -Tools }
    "4" {
        Set-Configuration
        Show-Menu
        $choice2 = Read-Host "Votre choix [1]"
        if ([string]::IsNullOrEmpty($choice2)) { $choice2 = "1" }
        switch ($choice2) {
            "1" { Start-Pipeline }
            "2" { Start-Pipeline -Background }
            "3" { Start-Pipeline -Tools }
            default { Write-Warn "Annule" }
        }
    }
    "q" { Write-Warn "Annule"; exit 0 }
    "Q" { Write-Warn "Annule"; exit 0 }
    default { Write-Err "Choix invalide"; exit 1 }
}
