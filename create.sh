#!/usr/bin/env bash
set -e

# ==============================================================================
# Central script to create Distrobox containers
# Run on the HOST (Fedora).
# Usage:
#   ./create.sh [environment-name]
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load optional local overrides from .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/.env"
fi

# Export environment defaults for Distrobox manifest evaluation
export FEDORA_VERSION="${FEDORA_VERSION:-44}"
export WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/Workspace}"
export DISTROBOX_HOMES_DIR="${DISTROBOX_HOMES_DIR:-$HOME/.local/share/distrobox-homes}"
export DISTROBOX_ADDITIONAL_FLAGS="${DISTROBOX_ADDITIONAL_FLAGS:---device /dev/kvm --device /dev/dri}"
export DISTROBOX_NVIDIA="${DISTROBOX_NVIDIA:-0}"
export DISTROBOX_PULL="${DISTROBOX_PULL:-1}"

INI_FILE="$SCRIPT_DIR/distrobox.ini"

if [ ! -f "$INI_FILE" ]; then
    echo "❌ Error: Manifest file '$INI_FILE' not found."
    exit 1
fi

if ! command -v distrobox >/dev/null 2>&1; then
    echo "❌ Error: 'distrobox' is not installed or not available on host."
    echo "   Install it with: sudo dnf install distrobox"
    exit 1
fi

# Get available environments from distrobox.ini
mapfile -t AVAILABLE_BOXES < <(grep -E '^\[.*\]$' "$INI_FILE" | tr -d '[]')

if [ ${#AVAILABLE_BOXES[@]} -eq 0 ]; then
    echo "❌ Error: No environments defined in $INI_FILE."
    exit 1
fi

BOX_NAME="$1"

# If no argument was provided, display interactive selection menu
if [ -z "$BOX_NAME" ]; then
    echo "======================================================="
    echo "  🚀 Distrobox Sandbox Creator"
    echo "======================================================="
    echo "Select the environment you wish to create:"
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

# Validate that the chosen environment exists in distrobox.ini
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

BOX_HOME="$DISTROBOX_HOMES_DIR/$BOX_NAME"

echo ""
echo "======================================================="
echo "  🚀 Creating Sandbox: $BOX_NAME"
echo "======================================================="
echo "  📁 Isolated Home: $BOX_HOME"
echo "  📂 Workspace:     $WORKSPACE_DIR"
echo "  📄 Manifest:      $INI_FILE"
echo "======================================================="

# Ensure isolated home directory exists on the host
mkdir -p "$BOX_HOME"

# Create or verify container using distrobox assemble
distrobox assemble create --file "$INI_FILE" --name "$BOX_NAME"

echo ""
echo "======================================================="
echo "  🎉 Sandbox '$BOX_NAME' ready!"
echo "======================================================="
echo "To access it, run from the host:"
echo "  ./enter.sh $BOX_NAME"
echo ""
echo "The first time inside the sandbox, run provisioning:"
echo "  bash $WORKSPACE_DIR/distrobox-configs/$BOX_NAME/setup.sh"
echo "======================================================="
