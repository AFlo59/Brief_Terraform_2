# =============================================================================
# Build Script - Data Pipeline Docker Image (PowerShell)
# =============================================================================
# Construit l'image Docker pour le pipeline de donnees
# Detecte les environnements Azure et propose le deploiement ACR
# Usage: .\build.ps1 [-NoCache] [-Pull] [-Auto] [-Deploy ENV]
# =============================================================================

param(
    [switch]$NoCache,
    [switch]$Pull,
    [switch]$Auto,
    [string]$Deploy,
    [switch]$Help
)

# Configuration
$ImageName = "nyc-taxi-pipeline"
$ImageTag = "latest"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
$DockerDir = Join-Path $ProjectRoot "docker"
$SharedDir = Join-Path (Split-Path -Parent $ProjectRoot) "shared"

# Variables globales pour les environnements
$script:AvailableEnvs = @()
$script:EnvAcrServers = @{}
$script:EnvAcrUsers = @{}
$script:EnvAcrPasswords = @{}

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

function Test-DockerLogin {
    try {
        docker pull --quiet hello-world 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            docker rmi hello-world 2>$null | Out-Null
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Invoke-DockerLogin {
    Write-Warn "Connexion a Docker Hub requise..."
    Write-Info "Creez un compte gratuit sur https://hub.docker.com si necessaire"
    Write-Host ""
    docker login
    return $LASTEXITCODE -eq 0
}

function Confirm-DockerCredentials {
    Write-Info "Verification de la connexion Docker..."
    
    if (-not (Test-DockerLogin)) {
        Write-Warn "Impossible de se connecter a Docker Hub"
        Write-Host ""
        
        $response = Read-Host "Voulez-vous vous connecter a Docker Hub? (o/n) [o]"
        if ([string]::IsNullOrEmpty($response)) { $response = "o" }
        
        if ($response -match "^[oOyY]") {
            $configPath = Join-Path $env:USERPROFILE ".docker\config.json"
            if (Test-Path $configPath) {
                Write-Info "Reinitialisation de la configuration Docker..."
                Remove-Item $configPath -Force
            }
            
            if (-not (Invoke-DockerLogin)) {
                Write-Err "Echec de la connexion"
                exit 1
            }
        }
        else {
            Write-Warn "Certaines images pourraient ne pas etre telechargeables"
        }
    }
    else {
        Write-Success "Connexion Docker fonctionnelle"
    }
    Write-Host ""
}

function Find-AzureEnvironments {
    $script:AvailableEnvs = @()
    $script:EnvAcrServers = @{}
    $script:EnvAcrUsers = @{}
    $script:EnvAcrPasswords = @{}
    
    foreach ($env in @("dev", "rec", "prod")) {
        $envFile = Join-Path $SharedDir ".env.$env"
        if (Test-Path $envFile) {
            $script:AvailableEnvs += $env
            
            # Lire le fichier .env
            $content = Get-Content $envFile -ErrorAction SilentlyContinue
            foreach ($line in $content) {
                if ($line -match "^ACR_LOGIN_SERVER=(.+)$") {
                    $script:EnvAcrServers[$env] = $Matches[1]
                }
                if ($line -match "^ACR_USERNAME=(.+)$") {
                    $script:EnvAcrUsers[$env] = $Matches[1]
                }
                if ($line -match "^ACR_PASSWORD=(.+)$") {
                    $script:EnvAcrPasswords[$env] = $Matches[1]
                }
            }
        }
    }
}

function Show-Status {
    Write-Status "Etat actuel:"
    
    # Image existante ?
    $imageExists = docker image inspect "${ImageName}:${ImageTag}" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $imageInfo = docker image inspect "${ImageName}:${ImageTag}" --format '{{.Size}}' 2>$null
        $sizeMB = [math]::Round($imageInfo / 1MB, 1)
        $created = docker image inspect "${ImageName}:${ImageTag}" --format '{{.Created}}' 2>$null
        $createdDate = $created.Substring(0, 10)
        Write-Host "  Image locale: " -NoNewline
        Write-Host "${ImageName}:${ImageTag}" -ForegroundColor Green -NoNewline
        Write-Host " ($sizeMB MB, $createdDate)"
    }
    else {
        Write-Host "  Image locale: " -NoNewline
        Write-Host "Non trouvee" -ForegroundColor Yellow
    }
    
    # Conteneurs en cours
    $running = docker ps --filter "ancestor=${ImageName}:${ImageTag}" --format '{{.Names}}' 2>$null
    if ($running) {
        $count = ($running | Measure-Object -Line).Lines
        Write-Host "  Conteneurs actifs: " -NoNewline
        Write-Host "$count" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Environnements Azure
    Write-Host "[AZURE] Environnements detectes:" -ForegroundColor Cyan
    if ($script:AvailableEnvs.Count -eq 0) {
        Write-Host "  " -NoNewline
        Write-Host "Aucun" -ForegroundColor Yellow -NoNewline
        Write-Host " - Deployez d'abord avec terraform_pipeline"
    }
    else {
        foreach ($env in $script:AvailableEnvs) {
            $acr = $script:EnvAcrServers[$env]
            if (-not $acr) { $acr = "N/A" }
            Write-Host "  [OK] " -ForegroundColor Green -NoNewline
            Write-Host "$env -> $acr"
        }
    }
    Write-Host ""
}

function Show-Menu {
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Blue
    Write-Host "         Build - NYC Taxi Data Pipeline                              " -ForegroundColor Blue
    Write-Host "======================================================================" -ForegroundColor Blue
    Write-Host ""
    Show-Status
    Write-Host "Choisissez une option :" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) " -NoNewline -ForegroundColor Green
    Write-Host "Build avec cache (rapide)"
    Write-Host "  2) " -NoNewline -ForegroundColor Yellow
    Write-Host "Build sans cache (reconstruction complete)"
    Write-Host "  3) " -NoNewline -ForegroundColor Blue
    Write-Host "Mettre a jour les images de base + build"
    
    # Options de deploiement si environnements detectes
    if ($script:AvailableEnvs.Count -gt 0) {
        Write-Host ""
        Write-Host "--- Deploiement Azure ---" -ForegroundColor Cyan
        $optNum = 4
        foreach ($env in $script:AvailableEnvs) {
            $acr = $script:EnvAcrServers[$env]
            Write-Host "  $optNum) " -NoNewline -ForegroundColor Blue
            Write-Host "Build + Deploy vers " -NoNewline
            Write-Host "$env" -ForegroundColor Green -NoNewline
            Write-Host " ($acr)"
            $optNum++
        }
    }
    
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
    
    Write-Success "Images de base telechargees"
    Write-Host ""
}

function Confirm-BaseImages {
    Write-Info "Verification des images de base..."
    
    $uvExists = docker image inspect "ghcr.io/astral-sh/uv:python3.11-bookworm-slim" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Telechargement de l'image uv..."
        docker pull ghcr.io/astral-sh/uv:python3.11-bookworm-slim
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Impossible de telecharger l'image uv"
            Write-Info "Essayez: docker login ghcr.io"
            exit 1
        }
    }
    
    $pythonExists = docker image inspect "python:3.11-slim-bookworm" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Telechargement de l'image Python..."
        docker pull python:3.11-slim-bookworm
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Impossible de telecharger l'image Python"
            exit 1
        }
    }
    
    Write-Success "Images de base pretes"
    Write-Host ""
}

function Build-Image {
    param([switch]$WithoutCache)
    
    $buildOpts = @()
    if ($WithoutCache) {
        $buildOpts += "--no-cache"
        Write-Warn "Mode sans cache active"
    }
    
    $dockerfilePath = Join-Path $DockerDir "Dockerfile"
    if (-not (Test-Path $dockerfilePath)) {
        Write-Err "Dockerfile non trouve: $dockerfilePath"
        exit 1
    }
    
    Confirm-BaseImages
    
    Write-Host "[BUILD] " -ForegroundColor Green -NoNewline
    Write-Host "Construction de l'image: ${ImageName}:${ImageTag}"
    Write-Info "Contexte de build: $ProjectRoot"
    Write-Host ""
    
    $buildArgs = @("build") + $buildOpts + @(
        "-t", "${ImageName}:${ImageTag}"
        "-f", $dockerfilePath
        $ProjectRoot
    )
    
    & docker @buildArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Success "Image construite avec succes!"
        return $true
    }
    else {
        Write-Err "Echec de la construction"
        return $false
    }
}

function Deploy-ToAcr {
    param([string]$Environment)
    
    $envFile = Join-Path $SharedDir ".env.$Environment"
    if (-not (Test-Path $envFile)) {
        Write-Err "Fichier .env.$Environment non trouve!"
        exit 1
    }
    
    $acrServer = $script:EnvAcrServers[$Environment]
    $acrUser = $script:EnvAcrUsers[$Environment]
    $acrPass = $script:EnvAcrPasswords[$Environment]
    
    if (-not $acrServer) {
        Write-Err "ACR_LOGIN_SERVER non trouve dans .env.$Environment"
        exit 1
    }
    
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Blue
    Write-Host "         Deploiement vers Azure Container Registry                   " -ForegroundColor Blue
    Write-Host "======================================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Info "Environnement: $Environment"
    Write-Info "ACR: $acrServer"
    Write-Host ""
    
    # Login ACR
    Write-Host "[ACR] Connexion a Azure Container Registry..." -ForegroundColor Cyan
    if ($acrPass) {
        $acrPass | docker login $acrServer -u $acrUser --password-stdin
    }
    else {
        # Fallback sur az acr login
        Write-Info "Utilisation de az acr login..."
        $acrName = $acrServer.Split('.')[0]
        az acr login --name $acrName
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Echec de la connexion ACR"
        exit 1
    }
    Write-Success "Connecte a ACR"
    Write-Host ""
    
    # Tag l'image
    $remoteTag = "${acrServer}/${ImageName}:${ImageTag}"
    Write-Host "[TAG] Tag de l'image: $remoteTag" -ForegroundColor Cyan
    docker tag "${ImageName}:${ImageTag}" $remoteTag
    
    # Push
    Write-Host "[PUSH] Envoi vers ACR..." -ForegroundColor Cyan
    docker push $remoteTag
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Green
        Write-Host "         DEPLOIEMENT TERMINE                                         " -ForegroundColor Green
        Write-Host "======================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Success "Image deployee: $remoteTag"
        Write-Host ""
        Write-Info "Le Container App va automatiquement detecter la nouvelle image."
        Write-Info "Verifiez dans le portail Azure: Container Apps > $Environment"
        Write-Host ""
    }
    else {
        Write-Err "Echec du push vers ACR"
        exit 1
    }
}

function Build-AndDeploy {
    param(
        [string]$Environment,
        [switch]$WithoutCache
    )
    
    Write-Host "[MODE] Build + Deploy vers " -ForegroundColor Cyan -NoNewline
    Write-Host "$Environment" -ForegroundColor Green
    Write-Host ""
    
    $buildResult = Build-Image -WithoutCache:$WithoutCache
    if ($buildResult) {
        Deploy-ToAcr -Environment $Environment
    }
}

function Show-NextSteps {
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "                    PROCHAINES ETAPES                                 " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Mode local (avec emulateurs):" -ForegroundColor Green
    Write-Host "  .\scripts\windows\docker\run-local.ps1"
    Write-Host ""
    Write-Host "Mode Azure (avec ressources cloud):" -ForegroundColor Blue
    Write-Host "  .\scripts\windows\docker\run-azure.ps1"
    Write-Host ""
    
    if ($script:AvailableEnvs.Count -gt 0) {
        Write-Host "Deployer vers Azure:" -ForegroundColor Yellow
        foreach ($env in $script:AvailableEnvs) {
            Write-Host "  .\scripts\windows\docker\build.ps1 -Deploy $env"
        }
        Write-Host ""
    }
    
    Write-Host "Arreter les services:" -ForegroundColor Red
    Write-Host "  .\scripts\windows\docker\stop.ps1"
    Write-Host ""
}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

# Aide
if ($Help) {
    Write-Host "Usage: .\build.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Auto           Build avec cache (par defaut)"
    Write-Host "  -NoCache        Build sans cache (reconstruction complete)"
    Write-Host "  -Pull           Pull images de base + build"
    Write-Host "  -Deploy ENV     Build + push vers ACR (dev|rec|prod)"
    Write-Host "  (aucun)         Affiche le menu interactif"
    exit 0
}

# Verifier Docker
if (-not (Test-DockerRunning)) {
    Write-Err "Docker n'est pas en cours d'execution!"
    Write-Info "Lancez Docker Desktop et reessayez."
    exit 1
}
Write-Success "Docker est en cours d'execution"

# Verifier credentials
Confirm-DockerCredentials

# Detecter les environnements Azure
Find-AzureEnvironments

# Argument -Deploy
if ($Deploy) {
    if ($Deploy -notin @("dev", "rec", "prod")) {
        Write-Err "Environnement invalide: $Deploy"
        Write-Info "Utilisez: dev, rec ou prod"
        exit 1
    }
    if ($Deploy -notin $script:AvailableEnvs) {
        Write-Err "Environnement $Deploy non disponible"
        Write-Info "Deployez d'abord avec terraform_pipeline"
        exit 1
    }
    Build-AndDeploy -Environment $Deploy -WithoutCache:$NoCache
    exit 0
}

# Arguments CLI
if ($NoCache) {
    Build-Image -WithoutCache
    Show-NextSteps
    exit 0
}

if ($Pull) {
    Get-BaseImages
    Build-Image
    Show-NextSteps
    exit 0
}

if ($Auto) {
    Build-Image
    Show-NextSteps
    exit 0
}

# Mode interactif
Show-Menu
$choice = Read-Host "Votre choix [1]"
if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }

switch ($choice) {
    "1" { 
        Build-Image
        Show-NextSteps
    }
    "2" { 
        Build-Image -WithoutCache
        Show-NextSteps
    }
    "3" { 
        Get-BaseImages
        Build-Image
        Show-NextSteps
    }
    "4" {
        if ($script:AvailableEnvs.Count -ge 1) {
            Build-AndDeploy -Environment $script:AvailableEnvs[0]
        }
        else {
            Write-Err "Choix invalide"
            exit 1
        }
    }
    "5" {
        if ($script:AvailableEnvs.Count -ge 2) {
            Build-AndDeploy -Environment $script:AvailableEnvs[1]
        }
        else {
            Write-Err "Choix invalide"
            exit 1
        }
    }
    "6" {
        if ($script:AvailableEnvs.Count -ge 3) {
            Build-AndDeploy -Environment $script:AvailableEnvs[2]
        }
        else {
            Write-Err "Choix invalide"
            exit 1
        }
    }
    "q" { Write-Warn "Annule"; exit 0 }
    "Q" { Write-Warn "Annule"; exit 0 }
    default { Write-Err "Choix invalide"; exit 1 }
}
