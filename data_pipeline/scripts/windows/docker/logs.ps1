# =============================================================================
# Logs Script - Voir les logs du pipeline (PowerShell)
# =============================================================================
# Usage: .\logs.ps1 [-Service "pipeline"] [-Follow] [-Lines 100]
# =============================================================================

param(
    [ValidateSet("pipeline", "postgres", "azurite", "pgadmin", "all")]
    [string]$Service = "pipeline",
    
    [switch]$Follow,
    [int]$Lines = 100,
    [switch]$Help
)

function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }

if ($Help) {
    Write-Host "Usage: .\logs.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Service    Service: pipeline, postgres, azurite, pgadmin, all"
    Write-Host "  -Follow     Suivre les logs en temps reel"
    Write-Host "  -Lines      Nombre de lignes (defaut: 100)"
    Write-Host "  -Help       Afficher cette aide"
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DockerDir = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))) "docker"
$ComposeFile = Join-Path $DockerDir "docker-compose.yml"

$logArgs = @("-f", $ComposeFile, "logs")

if ($Follow) {
    $logArgs += "-f"
}

$logArgs += @("--tail", $Lines.ToString())

if ($Service -ne "all") {
    $logArgs += $Service
}

Write-Info "Affichage des logs: $Service"
& docker compose @logArgs
