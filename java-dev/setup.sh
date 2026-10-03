#!/usr/bin/env bash
set -e

# ==============================================================================
# Java / JVM Tools Provisioning Script (java-dev)
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
JAVA_DEFAULT_VERSION="${JAVA_DEFAULT_VERSION:-21}"
INSTALL_GUI="${INSTALL_GUI:-true}"
INSTALL_GRADLE="${INSTALL_GRADLE:-true}"
INSTALL_MAVEN="${INSTALL_MAVEN:-true}"
INSTALL_KOTLIN="${INSTALL_KOTLIN:-true}"

echo "======================================================="
echo "  🛠️  Provisioning Java/JVM Sandbox Environment       "
echo "======================================================="
echo "Configuration:"
echo "  • Java LTS default:    $JAVA_DEFAULT_VERSION"
echo "  • GUI & Audio support: $INSTALL_GUI"
echo "  • Install Gradle:      $INSTALL_GRADLE"
echo "  • Install Maven:       $INSTALL_MAVEN"
echo "  • Install Kotlin CLI:  $INSTALL_KOTLIN"
echo "======================================================="

# 1. Verify execution inside container
if [ ! -f /run/host/container-manager ] && [ -z "$CONTAINER_ID" ] && [ ! -f /.dockerenv ]; then
    echo "⚠️  WARNING: It appears you are not inside a Distrobox container."
    echo "   Enter first from the host using:"
    echo "     ./enter.sh java-dev"
    echo ""
    read -rp "Are you sure you want to continue here? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# 2. Install system packages (utilities, GraalVM toolchain, and optional GUI/fonts)
echo ""
echo "📦 [1/6] Installing system dependencies (Base toolchain)..."
BASE_PACKAGES_FEDORA="curl wget zip unzip tar sed git which file jq findutils pciutils procps-ng gcc gcc-c++ glibc-devel zlib-devel libstdc++-devel"
GUI_PACKAGES_FEDORA="libglvnd-glx mesa-dri-drivers vulkan-loader xrandr gtk3 glib2 libX11 libXext libXdamage libXfixes libXcursor libXrandr libxkbcommon libXi libXrender libXtst libXinerama libXcomposite fontconfig freetype dejavu-sans-fonts dejavu-serif-fonts dejavu-sans-mono-fonts google-noto-sans-fonts google-noto-color-emoji-fonts pulseaudio-libs alsa-lib"

BASE_PACKAGES_DEBIAN="curl wget zip unzip tar sed git file jq build-essential zlib1g-dev pciutils procps"
GUI_PACKAGES_DEBIAN="libgl1-mesa-glx libgl1-mesa-dri libgtk-3-0 libx11-6 libxtst6 libxrender1 libxcursor1 libxrandr2 libxi6 fontconfig fonts-dejavu fonts-noto-color-emoji libpulse0 libasound2t64 libvulkan1"

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

# 3. Install SDKMAN! if not present
echo ""
echo "📦 [2/6] Setting up SDKMAN!..."
export SDKMAN_DIR="$HOME/.sdkman"
if [ ! -d "$SDKMAN_DIR" ]; then
    echo "📥 Downloading and installing SDKMAN!..."
    curl -s "https://get.sdkman.io" | bash
fi

# Configure non-interactive auto-answer in SDKMAN
mkdir -p "$SDKMAN_DIR/etc"
if [ -f "$SDKMAN_DIR/etc/config" ]; then
    sed -i -e 's/sdkman_auto_answer=false/sdkman_auto_answer=true/' "$SDKMAN_DIR/etc/config"
else
    echo "sdkman_auto_answer=true" > "$SDKMAN_DIR/etc/config"
fi

# Source SDKMAN in current session
# shellcheck source=/dev/null
source "$SDKMAN_DIR/bin/sdkman-init.sh"

# 4. Install Java LTS default (Eclipse Temurin)
echo ""
echo "☕ [3/6] Installing Java $JAVA_DEFAULT_VERSION LTS (Eclipse Temurin)..."
JAVA_TARGET_VERSION=$(sdk list java 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E "\|\s*${JAVA_DEFAULT_VERSION}\.[0-9].*tem" | awk -F'|' '{print $NF}' | tr -d ' ' | head -n 1)
if [ -z "$JAVA_TARGET_VERSION" ]; then
    JAVA_TARGET_VERSION="${JAVA_DEFAULT_VERSION}.0.12+1.1-tem"
fi
echo "Detected version: $JAVA_TARGET_VERSION"
sdk install java "$JAVA_TARGET_VERSION" || true
sdk default java "$JAVA_TARGET_VERSION" || true

# 5. Install Build Tools (Gradle & Maven)
echo ""
echo "🐘 [4/6] Installing Build Tools..."
if [ "$INSTALL_GRADLE" = "true" ]; then
    echo "   • Installing Gradle..."
    sdk install gradle || true
else
    echo "   • Skipping Gradle (INSTALL_GRADLE=false)"
fi

if [ "$INSTALL_MAVEN" = "true" ]; then
    echo "   • Installing Maven..."
    sdk install maven || true
else
    echo "   • Skipping Maven (INSTALL_MAVEN=false)"
fi

# 6. Install Kotlin
echo ""
echo "💜 [5/6] Configuring Kotlin CLI..."
if [ "$INSTALL_KOTLIN" = "true" ]; then
    echo "   • Installing Kotlin CLI..."
    sdk install kotlin || true
else
    echo "   • Skipping Kotlin CLI (INSTALL_KOTLIN=false)"
fi

# 7. Configure environment variables in .bashrc
echo ""
echo "⚙️  [6/6] Configuring environment variables in ~/.bashrc..."
if ! grep -q "SDKMAN_DIR" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo ""
        echo "# SDKMAN Configuration (Distrobox Sandbox java-dev)"
        echo "export SDKMAN_DIR=\"\$HOME/.sdkman\""
        echo "[[ -s \"\$HOME/.sdkman/bin/sdkman-init.sh\" ]] && source \"\$HOME/.sdkman/bin/sdkman-init.sh\""
    } >> "$HOME/.bashrc"
fi

if ! grep -q "JAVA_HOME" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo "export JAVA_HOME=\"\$HOME/.sdkman/candidates/java/current\""
        echo "export PATH=\"\$JAVA_HOME/bin:\$HOME/.local/bin:\$PATH\""
    } >> "$HOME/.bashrc"
fi

if [ -n "$GRADLE_OPTS" ] && ! grep -q "GRADLE_OPTS" "$HOME/.bashrc" 2>/dev/null; then
    echo "export GRADLE_OPTS=\"$GRADLE_OPTS\"" >> "$HOME/.bashrc"
fi


# 8. Install CLI tools from bin/ into ~/.local/bin
if [ -d "$SCRIPT_DIR/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    cp -r "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/"*
fi

chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo ""
echo "======================================================="
echo "  🎉 Sandbox java-dev provisioning completed!          "
echo "======================================================="
echo "Installed tools ready in sandbox:"
echo "  • Java:    $(java -version 2>&1 | head -n 1)"
echo "  • Gradle:  $(gradle --version 2>&1 | grep '^Gradle ' || echo 'Gradle installed')"
echo "  • Maven:   $(mvn -version 2>&1 | head -n 1 || echo 'Maven installed')"
echo "  • Kotlin:  $(kotlinc -version 2>&1 || echo 'Kotlin installed')"
echo ""
echo "Available commands in this sandbox:"
echo "  • Version manager: change_version [list|remote|<version>]"
echo "  • Direct SDKMAN:   sdk list java, sdk use java <version>"
echo "======================================================="
