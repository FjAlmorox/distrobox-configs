#!/usr/bin/env bash
set -e

# ==============================================================================
# Central script to enter Distrobox containers
# Run on the HOST (Fedora), or inside a nested Distrobox (delegates to the host).
# Usage:
#   ./enter.sh [environment-name]
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared helper library (environment detection, host delegation, paths)
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/scripts/lib.sh"

# Load optional local overrides from .env (no assumption about repo folder name)
dbx_load_env "$SCRIPT_DIR"

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/Workspace}"
INI_FILE="$SCRIPT_DIR/distrobox.ini"

if ! dbx_require_distrobox; then
    exit 1
fi

# Get available environments
mapfile -t AVAILABLE_BOXES < <(grep -E '^\[.*\]$' "$INI_FILE" 2>/dev/null | tr -d '[]')

if [ ${#AVAILABLE_BOXES[@]} -eq 0 ]; then
    echo "❌ Error: No environments defined in $INI_FILE."
    exit 1
fi

BOX_NAME="$1"

# If no argument was provided, display interactive selection menu
if [ -z "$BOX_NAME" ]; then
    echo "======================================================="
    echo "  🚪 Enter Distrobox Sandboxes"
    echo "======================================================="
    echo "Select the environment you wish to enter:"
    PS3="Choose an option (1-${#AVAILABLE_BOXES[@]}): "
    select chosen in "${AVAILABLE_BOXES[@]}"; do
        if [ -n "$chosen" ]; then
            BOX_NAME="$chosen"
            break
        else
            echo "Invalid option. Please try again."
        fi
    done
fi

# Validate that the chosen environment exists
FOUND=false
for b in "${AVAILABLE_BOXES[@]}"; do
    if [ "$b" == "$BOX_NAME" ]; then
        FOUND=true
        break
    fi
done

if [ "$FOUND" = false ]; then
    echo "❌ Error: Environment '$BOX_NAME' is not defined in $INI_FILE."
    echo "   Available environments: ${AVAILABLE_BOXES[*]}"
    exit 1
fi

# Enter container and navigate directly to the Workspace
# (delegates to the host automatically when run inside a nested container)
dbx_exec_host_distrobox enter "$BOX_NAME" -- bash -c "cd '$WORKSPACE_DIR' && exec bash"
