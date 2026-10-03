#!/usr/bin/env bash
set -e

# ==============================================================================
# Python Tools Provisioning Script (python-dev)
# MUST BE EXECUTED INSIDE THE SANDBOX (DISTROBOX) ONLY
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-${DISTROBOX_HOST_HOME:-/home/$(id -un)}/Workspace}"

# Load optional local overrides from .env if present
if [ -f "$WORKSPACE_DIR/distrobox-configs/.env" ]; then
    # shellcheck source=/dev/null
    source "$WORKSPACE_DIR/distrobox-configs/.env"
elif [ -f "$HOME/.env" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.env"
fi

# Configurable defaults (overridable via environment variables or .env)
PYTHON_DEFAULT_VERSION="${PYTHON_DEFAULT_VERSION:-3.13}"
INSTALL_GUI="${INSTALL_GUI:-false}"
INSTALL_PYTHON_DEV_TOOLS="${INSTALL_PYTHON_DEV_TOOLS:-true}"

echo "======================================================="
echo "  🛠️  Provisioning Python Sandbox Environment          "
echo "======================================================="
echo "Configuration:"
echo "  • Python default:          $PYTHON_DEFAULT_VERSION"
echo "  • GUI & Audio support:     $INSTALL_GUI"
echo "  • Install Python CLI tools: $INSTALL_PYTHON_DEV_TOOLS"
echo "======================================================="

# 1. Verify execution inside container
if [ ! -f /run/host/container-manager ] && [ -z "$CONTAINER_ID" ] && [ ! -f /.dockerenv ]; then
    echo "⚠️  WARNING: It appears you are not inside a Distrobox container."
    echo "   Enter first from the host using:"
    echo "     ./enter.sh python-dev"
    echo ""
    read -rp "Are you sure you want to continue here? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# 2. Install system packages (utilities, C/C++ compilation headers, and optional GUI/fonts)
echo ""
echo "📦 [1/5] Installing system dependencies (Base toolchain & C headers)..."
BASE_PACKAGES_FEDORA="curl wget zip unzip tar sed git which file jq findutils pciutils procps-ng gcc gcc-c++ make glibc-devel libffi-devel openssl-devel sqlite-devel zlib-devel bzip2-devel readline-devel xz-devel libstdc++-devel"
GUI_PACKAGES_FEDORA="libglvnd-glx mesa-dri-drivers vulkan-loader xrandr gtk3 glib2 libX11 libXext libXdamage libXfixes libXcursor libXrandr libxkbcommon libXi libXrender libXtst libXinerama libXcomposite fontconfig freetype dejavu-sans-fonts dejavu-serif-fonts dejavu-sans-mono-fonts google-noto-sans-fonts google-noto-color-emoji-fonts pulseaudio-libs alsa-lib tk-devel"

BASE_PACKAGES_DEBIAN="curl wget zip unzip tar sed git file jq build-essential libffi-dev libssl-dev libsqlite3-dev zlib1g-dev libbz2-dev libreadline-dev liblzma-dev pciutils procps"
GUI_PACKAGES_DEBIAN="libgl1-mesa-glx libgl1-mesa-dri libgtk-3-0 libx11-6 libxtst6 libxrender1 libxcursor1 libxrandr2 libxi6 fontconfig fonts-dejavu fonts-noto-color-emoji libpulse0 libasound2t64 libvulkan1 tk-dev"

if command -v dnf >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL="$BASE_PACKAGES_FEDORA"
    if [ "$INSTALL_GUI" = "true" ]; then
        echo "   (Including GUI, fonts, and audio libraries)"
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $GUI_PACKAGES_FEDORA"
    else
        echo "   (Headless mode: skipping GUI, fonts, and audio libraries)"
    fi
    # shellcheck disable=SC2086
    sudo dnf install -y --skip-unavailable $PACKAGES_TO_INSTALL
elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    PACKAGES_TO_INSTALL="$BASE_PACKAGES_DEBIAN"
    if [ "$INSTALL_GUI" = "true" ]; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $GUI_PACKAGES_DEBIAN"
    fi
    # shellcheck disable=SC2086
    sudo apt-get install -y $PACKAGES_TO_INSTALL
fi

# 3. Install Astral uv
echo ""
echo "🚀 [2/5] Setting up Astral uv..."
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    echo "📥 Downloading and installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$HOME/.local/bin" sh
else
    echo "ℹ️ uv already installed. Updating..."
    uv self update 2>/dev/null || true
fi

# 4. Install target Python version via uv and configure default symlinks
echo ""
echo "🐍 [3/5] Installing Python $PYTHON_DEFAULT_VERSION via uv..."
uv python install "$PYTHON_DEFAULT_VERSION"

PYTHON_BIN=$(uv python find "$PYTHON_DEFAULT_VERSION" 2>/dev/null || true)
if [ -n "$PYTHON_BIN" ] && [ -x "$PYTHON_BIN" ]; then
    echo "Linking default python executables to $PYTHON_BIN..."
    ln -sf "$PYTHON_BIN" "$HOME/.local/bin/python3"
    ln -sf "$PYTHON_BIN" "$HOME/.local/bin/python"
fi

# 5. Install standard Python developer CLI tools via uv tool
echo ""
echo "🛠️  [4/5] Installing developer CLI tools via uv tool..."
if [ "$INSTALL_PYTHON_DEV_TOOLS" = "true" ]; then
    DEV_TOOLS=("ruff" "mypy" "pytest" "ipython" "pre-commit")
    for tool in "${DEV_TOOLS[@]}"; do
        echo "   • Installing/updating $tool..."
        uv tool install "$tool" --upgrade 2>/dev/null || uv tool install "$tool" || true
    done
else
    echo "   • Skipping developer CLI tools (INSTALL_PYTHON_DEV_TOOLS=false)"
fi

# 6. Configure environment variables and shell completion in ~/.bashrc
echo ""
echo "⚙️  [5/5] Configuring environment in ~/.bashrc..."
if ! grep -q "DISTROBOX_PYTHON_DEV" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo ""
        echo "# =============================================================================="
        echo "# Distrobox Sandbox Environment (python-dev) - DISTROBOX_PYTHON_DEV"
        echo "# =============================================================================="
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo "if command -v uv >/dev/null 2>&1; then"
        echo "    eval \"\$(uv generate-shell-completion bash 2>/dev/null || true)\""
        echo "fi"
    } >> "$HOME/.bashrc"
fi

# 7. Install CLI commands from bin/ into ~/.local/bin
if [ -d "$SCRIPT_DIR/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    cp -r "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/"*
fi

chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo ""
echo "======================================================="
echo "  🎉 Sandbox python-dev provisioning completed!        "
echo "======================================================="
echo "Installed tools ready in sandbox:"
echo "  • uv:      $(uv --version 2>/dev/null || echo 'uv installed')"
echo "  • Python:  $(python3 --version 2>/dev/null || echo 'Python installed')"
if [ "$INSTALL_PYTHON_DEV_TOOLS" = "true" ]; then
    echo "  • Ruff:    $(ruff --version 2>/dev/null || echo 'ruff installed')"
    echo "  • Mypy:    $(mypy --version 2>/dev/null || echo 'mypy installed')"
    echo "  • Pytest:  $(pytest --version 2>/dev/null || echo 'pytest installed')"
    echo "  • IPython: $(ipython --version 2>/dev/null || echo 'ipython installed')"
fi
echo ""
echo "Available commands in this sandbox:"
echo "  • Version manager: change_version [list|remote|<version>]"
echo "  • Fast runner:     uv run, uv run --with <pkg> <script>"
echo "  • Package manager: uv add, uv remove, uv sync"
echo "======================================================="
