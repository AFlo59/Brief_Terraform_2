#!/bin/bash
# =============================================================================
# Remove Script - Data Pipeline Docker Resources
# =============================================================================
# Alias vers stop.sh pour la cohérence avec terraform_pipeline
# Usage: ./remove.sh [options]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Appeler stop.sh avec les mêmes arguments
exec "$SCRIPT_DIR/stop.sh" "$@"
