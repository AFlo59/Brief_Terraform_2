# =============================================================================
# Check Prerequisites Script (PowerShell)
# =============================================================================
# Verifie que tous les outils necessaires sont installes
# Usage: .\check-prereqs.ps1
# =============================================================================

$ErrorCount = 0

function Write-Check {
    param($Name, $Status, $Details = "")
    if ($Status) {
        Write-Host "[OK]    " -ForegroundColor Green -NoNewline
        Write-Host "$Name" -NoNewline
        if ($Details) { Write-Host " ($Details)" -ForegroundColor Gray }
        else { Write-Host "" }
    }
    else {
        Write-Host "[FAIL]  " -ForegroundColor Red -NoNewline
        Write-Host "$Name" -ForegroundColor Yellow
        $script:ErrorCount++
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "    Verification des prerequis - NYC Taxi Pipeline             " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------
Write-Host "Docker:" -ForegroundColor White
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if ($dockerVersion) {
        Write-Check "Docker Engine" $true "v$dockerVersion"
        
        # Verifier si Docker est en cours d'execution
        $dockerRunning = docker info 2>$null
        Write-Check "Docker Running" ($null -ne $dockerRunning)
    }
    else {
        Write-Check "Docker Engine" $false
    }
}
catch {
    Write-Check "Docker Engine" $false
}
Write-Host ""

# -----------------------------------------------------------------------------
# Azure CLI
# -----------------------------------------------------------------------------
Write-Host "Azure CLI:" -ForegroundColor White
try {
    $azVersion = az version --query '"azure-cli"' -o tsv 2>$null
    if ($azVersion) {
        Write-Check "Azure CLI" $true "v$azVersion"
        
        # Verifier la connexion Azure
        $azAccount = az account show 2>$null | ConvertFrom-Json
        if ($azAccount) {
            Write-Check "Azure Login" $true "$($azAccount.name)"
        }
        else {
            Write-Host "[WARN]  " -ForegroundColor Yellow -NoNewline
            Write-Host "Azure Login - Non connecte (az login requis)"
        }
    }
    else {
        Write-Check "Azure CLI" $false
    }
}
catch {
    Write-Check "Azure CLI" $false
}
Write-Host ""

# -----------------------------------------------------------------------------
# Fichiers de configuration
# -----------------------------------------------------------------------------
Write-Host "Configuration:" -ForegroundColor White
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
$TerraformDir = Join-Path $ProjectRoot "terraform"

# Verifier les fichiers d'environnement
$devTfvars = Test-Path (Join-Path $TerraformDir "environments\dev.tfvars")
Write-Check "environments/dev.tfvars" $devTfvars

$recTfvars = Test-Path (Join-Path $TerraformDir "environments\rec.tfvars")
Write-Check "environments/rec.tfvars" $recTfvars

$prodTfvars = Test-Path (Join-Path $TerraformDir "environments\prod.tfvars")
Write-Check "environments/prod.tfvars" $prodTfvars

# Verifier secrets.tfvars
$secretsTfvars = Join-Path $TerraformDir "environments\secrets.tfvars"
if (Test-Path $secretsTfvars) {
    $secretsContent = Get-Content $secretsTfvars -Raw
    if ($secretsContent -match "CHANGEZ_MOI") {
        Write-Host "[WARN]  " -ForegroundColor Yellow -NoNewline
        Write-Host "secrets.tfvars - Mot de passe par defaut detecte!"
    }
    else {
        Write-Check "environments/secrets.tfvars" $true "Configure"
    }
}
else {
    Write-Host "[WARN]  " -ForegroundColor Yellow -NoNewline
    Write-Host "secrets.tfvars - Fichier manquant"
}
Write-Host ""

# -----------------------------------------------------------------------------
# Fichiers Terraform
# -----------------------------------------------------------------------------
Write-Host "Fichiers Terraform:" -ForegroundColor White
$tfFiles = @("main.tf", "variables.tf", "outputs.tf", "providers.tf")
foreach ($file in $tfFiles) {
    $exists = Test-Path (Join-Path $TerraformDir $file)
    Write-Check $file $exists
}
Write-Host ""

# -----------------------------------------------------------------------------
# Docker Image
# -----------------------------------------------------------------------------
Write-Host "Image Docker Terraform:" -ForegroundColor White
try {
    $imageExists = docker image inspect "terraform-azure-workspace:latest" 2>$null
    if ($imageExists) {
        Write-Check "terraform-azure-workspace:latest" $true "Prete"
    }
    else {
        Write-Host "[INFO]  " -ForegroundColor Cyan -NoNewline
        Write-Host "Image non construite - Executez: .\scripts\windows\docker\build.ps1"
    }
}
catch {
    Write-Host "[INFO]  " -ForegroundColor Cyan -NoNewline
    Write-Host "Image non construite - Executez: .\scripts\windows\docker\build.ps1"
}
Write-Host ""

# -----------------------------------------------------------------------------
# Resume
# -----------------------------------------------------------------------------
Write-Host "================================================================" -ForegroundColor Cyan
if ($ErrorCount -eq 0) {
    Write-Host "  Tous les prerequis sont satisfaits!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Prochaine etape:" -ForegroundColor White
    Write-Host "    1. .\scripts\windows\docker\build.ps1   (construire l'image)"
    Write-Host "    2. .\scripts\windows\docker\run.ps1     (lancer le workspace)"
}
else {
    Write-Host "  $ErrorCount prerequis manquant(s)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Actions requises:" -ForegroundColor White
    Write-Host "    - Installez les outils manquants"
    Write-Host "    - Relancez ce script pour verifier"
}
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
