# =============================================================================
# Remove Script - Data Pipeline Docker Resources (PowerShell)
# =============================================================================
# Alias vers stop.ps1 pour la coherence avec terraform_pipeline
# Usage: .\remove.ps1 [options]
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Appeler stop.ps1 avec les memes arguments
& "$ScriptDir\stop.ps1" @args
