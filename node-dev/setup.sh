#!/usr/bin/env bash
set -e

# ==============================================================================
# Node.js & Frontend Tools Provisioning Script (node-dev)
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
NODE_DEFAULT_VERSION="${NODE_DEFAULT_VERSION:-24}"
INSTALL_GUI="${INSTALL_GUI:-false}"
INSTALL_BUN="${INSTALL_BUN:-true}"
INSTALL_BROWSER_DEPS="${INSTALL_BROWSER_DEPS:-true}"

echo "======================================================="
echo "  🛠️  Provisioning Node / Frontend Sandbox Environment "
echo "======================================================="
echo "Configuration:"
echo "  • Node.js default LTS:     $NODE_DEFAULT_VERSION"
echo "  • GUI & Audio support:     $INSTALL_GUI"
echo "  • Headless Browser Testing: $INSTALL_BROWSER_DEPS"
echo "  • Install Bun runtime:     $INSTALL_BUN"
echo "======================================================="

# 1. Verify execution inside container
if [ ! -f /run/host/container-manager ] && [ -z "$CONTAINER_ID" ] && [ ! -f /.dockerenv ]; then
    echo "⚠️  WARNING: It appears you are not inside a Distrobox container."
    echo "   Enter first from the host using:"
    echo "     ./enter.sh node-dev"
    echo ""
    read -rp "Are you sure you want to continue here? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# 2. Install system packages (utilities, C/C++ compilation headers, and testing dependencies)
echo ""
echo "📦 [1/6] Installing system dependencies (Base toolchain & C++ headers)..."
BASE_PACKAGES_FEDORA="curl wget zip unzip tar sed git which file jq findutils pciutils procps-ng gcc gcc-c++ make python3 glibc-devel libstdc++-devel"
BROWSER_PACKAGES_FEDORA="nss atk at-spi2-atk cups-libs libdrm libXcomposite libXdamage libXrandr mesa-libgbm pango alsa-lib libxshmfence libxkbcommon"
GUI_PACKAGES_FEDORA="libglvnd-glx mesa-dri-drivers vulkan-loader xrandr gtk3 glib2 libX11 libXext libXfixes libXcursor libXi libXrender libXtst libXinerama fontconfig freetype dejavu-sans-fonts google-noto-sans-fonts google-noto-color-emoji-fonts pulseaudio-libs"

BASE_PACKAGES_DEBIAN="curl wget zip unzip tar sed git file jq build-essential python3 pciutils procps"
BROWSER_PACKAGES_DEBIAN="libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 libasound2t64 libxshmfence1 libxkbcommon0"
GUI_PACKAGES_DEBIAN="libgl1-mesa-glx libgl1-mesa-dri libgtk-3-0 libx11-6 libxtst6 libxrender1 libxcursor1 libxrandr2 libxi6 fontconfig fonts-dejavu fonts-noto-color-emoji libpulse0 libvulkan1"

if command -v dnf >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL="$BASE_PACKAGES_FEDORA"
    if [ "$INSTALL_BROWSER_DEPS" = "true" ]; then
        echo "   (Including Headless Browser Testing libraries for Playwright/Cypress)"
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $BROWSER_PACKAGES_FEDORA"
    fi
    if [ "$INSTALL_GUI" = "true" ]; then
        echo "   (Including Full Desktop GUI, fonts, and audio libraries)"
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $GUI_PACKAGES_FEDORA"
    else
        echo "   (Headless mode: skipping desktop windowing packages)"
    fi
    # shellcheck disable=SC2086
    sudo dnf install -y --skip-unavailable $PACKAGES_TO_INSTALL
elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    PACKAGES_TO_INSTALL="$BASE_PACKAGES_DEBIAN"
    if [ "$INSTALL_BROWSER_DEPS" = "true" ]; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $BROWSER_PACKAGES_DEBIAN"
    fi
    if [ "$INSTALL_GUI" = "true" ]; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $GUI_PACKAGES_DEBIAN"
    fi
    # shellcheck disable=SC2086
    sudo apt-get install -y $PACKAGES_TO_INSTALL
fi

# 3. Install fnm (Fast Node Manager)
echo ""
echo "🚀 [2/6] Installing fnm (Fast Node Manager)..."
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v fnm >/dev/null 2>&1; then
    echo "📥 Downloading fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell
fi

# Initialize fnm in current subshell
eval "$(fnm env --shell bash)"

# 4. Install Node.js LTS default
echo ""
echo "🟢 [3/6] Installing Node.js $NODE_DEFAULT_VERSION LTS via fnm..."
fnm install "$NODE_DEFAULT_VERSION"
fnm default "$NODE_DEFAULT_VERSION"
fnm use "$NODE_DEFAULT_VERSION"

# 5. Configure Corepack, pnpm and Yarn
echo ""
echo "📦 [4/6] Configuring pnpm and Corepack..."
corepack enable 2>/dev/null || true
corepack prepare pnpm@latest --activate 2>/dev/null || npm install -g pnpm 2>/dev/null || true
corepack prepare yarn@stable --activate 2>/dev/null || true

# 6. Install Bun (optional)
if [ "$INSTALL_BUN" = "true" ]; then
    echo ""
    echo "⚡ [5/6] Setting up Bun runtime & package manager..."
    if ! command -v bun >/dev/null 2>&1; then
        echo "📥 Downloading Bun..."
        curl -fsSL https://bun.sh/install | bash
    fi
    if [ -f "$HOME/.bun/bin/bun" ]; then
        ln -sf "$HOME/.bun/bin/bun" "$HOME/.local/bin/bun"
        ln -sf "$HOME/.bun/bin/bunx" "$HOME/.local/bin/bunx"
    fi
else
    echo "   • Skipping Bun (INSTALL_BUN=false)"
fi

# 7. Configure environment variables in ~/.bashrc
echo ""
echo "⚙️  [6/6] Configuring environment in ~/.bashrc..."
if ! grep -q "DISTROBOX_NODE_DEV" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo ""
        echo "# =============================================================================="
        echo "# Distrobox Sandbox Environment (node-dev) - DISTROBOX_NODE_DEV"
        echo "# =============================================================================="
        echo "export PATH=\"\$HOME/.local/bin:\$HOME/.bun/bin:\$PATH\""
        echo "if command -v fnm >/dev/null 2>&1; then"
        echo "    eval \"\$(fnm env --use-on-cd --shell bash)\""
        echo "fi"
        echo "if [ -d \"\$HOME/.bun/bin\" ]; then"
        echo "    export BUN_INSTALL=\"\$HOME/.bun\""
        echo "    export PATH=\"\$BUN_INSTALL/bin:\$PATH\""
        echo "fi"
    } >> "$HOME/.bashrc"
fi

# 8. Install CLI commands from bin/ into ~/.local/bin
if [ -d "$SCRIPT_DIR/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    cp -r "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/"*
fi

chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo ""
echo "======================================================="
echo "  🎉 Sandbox node-dev provisioning completed!          "
echo "======================================================="
echo "Installed tools ready in sandbox:"
echo "  • Node.js: $(node -v 2>/dev/null || echo 'Installed')"
echo "  • npm:     $(npm -v 2>/dev/null || echo 'Installed')"
echo "  • pnpm:    $(pnpm -v 2>/dev/null || echo 'Installed')"
echo "  • yarn:    $(yarn -v 2>/dev/null || echo 'Installed')"
if [ "$INSTALL_BUN" = "true" ]; then
    echo "  • Bun:     $(bun -v 2>/dev/null || echo 'Installed')"
fi
echo ""
echo "Available commands in this sandbox:"
echo "  • Version manager: change_version [list|remote|<version>]"
echo "  • Fast Node:       fnm use <version>, fnm install <version>"
echo "  • Package tools:   pnpm, npm, yarn, bun"
echo "======================================================="
