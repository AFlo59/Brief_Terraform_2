# =============================================================================
# Deploy Script - Deploiement par environnement (PowerShell)
# =============================================================================
# Usage: .\deploy.ps1 -Env <env> -Action <action>
#   Env:    dev | rec | prod
#   Action: plan | apply | destroy
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "rec", "prod")]
    [string]$Env,
    
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Action = "plan",
    
    [switch]$Help
)

# Fonctions d'affichage
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Aide
if ($Help) {
    Write-Host "Usage: .\deploy.ps1 -Env <env> [-Action <action>]"
    Write-Host ""
    Write-Host "Environnements:"
    Write-Host "  dev   - Developpement"
    Write-Host "  rec   - Recette (staging)"
    Write-Host "  prod  - Production"
    Write-Host ""
    Write-Host "Actions:"
    Write-Host "  plan    - Previsualiser les changements (defaut)"
    Write-Host "  apply   - Appliquer les changements"
    Write-Host "  destroy - Detruire l'infrastructure"
    exit 0
}

# Chemins
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
$TerraformDir = Join-Path $ProjectRoot "terraform"
$EnvFile = Join-Path $TerraformDir "environments\$Env.tfvars"
$SecretsFile = Join-Path $TerraformDir "environments\secrets.tfvars"

# Verifications
if (-not (Test-Path $EnvFile)) {
    Write-Err "Fichier d'environnement non trouve: $EnvFile"
    exit 1
}

# Banniere
Write-Host ""
Write-Host "================================================================" -ForegroundColor Blue
Write-Host "       Terraform Deployment - NYC Taxi Pipeline                 " -ForegroundColor Blue
Write-Host "================================================================" -ForegroundColor Blue
Write-Host ""
Write-Host "Environnement: " -NoNewline
Write-Host $Env -ForegroundColor Green
Write-Host "Action:        " -NoNewline
Write-Host $Action -ForegroundColor Yellow
Write-Host ""

# Confirmation pour destroy en prod
if ($Action -eq "destroy" -and $Env -eq "prod") {
    Write-Host "ATTENTION: Vous etes sur le point de DETRUIRE l'environnement PRODUCTION !" -ForegroundColor Red
    $Confirm = Read-Host "Tapez 'DESTROY PROD' pour confirmer"
    if ($Confirm -ne "DESTROY PROD") {
        Write-Warn "Operation annulee"
        exit 0
    }
}

# Changement vers le dossier Terraform
Set-Location $TerraformDir

# Initialisation si necessaire
if (-not (Test-Path ".terraform")) {
    Write-Info "Initialisation de Terraform..."
    terraform init
}

# Construction des arguments var-file
$VarFiles = @("-var-file=environments\$Env.tfvars")
if (Test-Path $SecretsFile) {
    $VarFiles += "-var-file=environments\secrets.tfvars"
}
else {
    Write-Warn "Fichier secrets.tfvars non trouve"
    Write-Host "Creez-le avec: cp environments\secrets.tfvars.example environments\secrets.tfvars"
}

# Execution de l'action
Write-Host ""
Write-Info "terraform $Action $($VarFiles -join ' ')"
Write-Host "----------------------------------------------------------------"

switch ($Action) {
    "plan" {
        $terraformArgs = @("plan") + $VarFiles
        & terraform @terraformArgs
    }
    "apply" {
        $terraformArgs = @("apply") + $VarFiles + @("-auto-approve")
        & terraform @terraformArgs
    }
    "destroy" {
        $terraformArgs = @("destroy") + $VarFiles + @("-auto-approve")
        & terraform @terraformArgs
    }
}

Write-Host ""
Write-Success "Operation terminee!"
