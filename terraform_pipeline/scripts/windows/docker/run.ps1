# =============================================================================
# Run Script - Terraform Interactive Workspace (PowerShell)
# =============================================================================
# Lance un conteneur interactif pour executer des commandes Terraform
# Usage: .\run.ps1 [-Detach] [-Cmd "commande"]
# =============================================================================

param(
    [switch]$Detach,
    [string]$Cmd = "",
    [switch]$Help
)

# Configuration
$ImageName = "terraform-azure-workspace"
$ImageTag = "latest"
$ContainerName = "terraform-workspace"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
$TerraformDir = Join-Path $ProjectRoot "terraform"
$MainProjectDir = Split-Path -Parent $ProjectRoot

# Fonctions d'affichage
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Run { param($Message) Write-Host "[RUN] $Message" -ForegroundColor Green }

# Aide
if ($Help) {
    Write-Host "Usage: .\run.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Detach     Lancer en arriere-plan"
    Write-Host "  -Cmd        Executer une commande specifique"
    Write-Host "  -Help       Afficher cette aide"
    exit 0
}

Write-Run "Demarrage du workspace Terraform"
Write-Host ""

# Verifier si l'image existe
$imageExists = docker image inspect "${ImageName}:${ImageTag}" 2>$null
if (-not $imageExists) {
    Write-Warn "Image non trouvee. Construction en cours..."
    & "$ScriptDir\build.ps1"
}

# Arreter et supprimer le conteneur existant si necessaire
$existingContainer = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $ContainerName }
if ($existingContainer) {
    Write-Info "Arret du conteneur existant..."
    docker rm -f $ContainerName 2>$null | Out-Null
}

# Creation du dossier terraform s'il n'existe pas
if (-not (Test-Path $TerraformDir)) {
    New-Item -ItemType Directory -Path $TerraformDir -Force | Out-Null
}

# Chemins Windows -> format Docker
$TerraformDirDocker = $TerraformDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
$DataPipelineDir = Join-Path $MainProjectDir "data_pipeline"
$DataPipelineDirDocker = $DataPipelineDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
$SharedDir = Join-Path $MainProjectDir "shared"
$SharedDirDocker = $SharedDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# Creer le dossier shared s'il n'existe pas
if (-not (Test-Path $SharedDir)) {
    New-Item -ItemType Directory -Path $SharedDir -Force | Out-Null
}

Write-Info "Montage des volumes:"
Write-Host "  - Terraform config: $TerraformDir -> /workspace/terraform"
Write-Host "  - Shared (env):     $SharedDir -> /workspace/shared"
Write-Host "  - data_pipeline:    $DataPipelineDir -> /workspace/data_pipeline (read-only)"
Write-Host ""

# Options Docker
$DockerOpts = @("-it")
if ($Detach) {
    $DockerOpts = @("-d")
}

# Execution du conteneur
try {
    if ($Cmd) {
        Write-Run "Commande: $Cmd"
        $dockerArgs = @(
            "run", "--rm"
        ) + $DockerOpts + @(
            "--name", $ContainerName
            "-v", "${TerraformDirDocker}:/workspace/terraform"
            "-v", "${SharedDirDocker}:/workspace/shared"
            "-v", "${DataPipelineDirDocker}:/workspace/data_pipeline:ro"
            "-w", "/workspace/terraform"
            "${ImageName}:${ImageTag}"
            "bash", "-c", $Cmd
        )
        & docker @dockerArgs
    }
    else {
        Write-Run "Mode interactif"
        $dockerArgs = @(
            "run", "--rm"
        ) + $DockerOpts + @(
            "--name", $ContainerName
            "-v", "${TerraformDirDocker}:/workspace/terraform"
            "-v", "${SharedDirDocker}:/workspace/shared"
            "-v", "${DataPipelineDirDocker}:/workspace/data_pipeline:ro"
            "-w", "/workspace/terraform"
            "${ImageName}:${ImageTag}"
        )
        & docker @dockerArgs
    }
}
catch {
    Write-Err "Erreur lors de l'execution: $_"
    exit 1
}
