#!/usr/bin/env bash
set -e

# ==============================================================================
# Android Tools Provisioning Script
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
ANDROID_COMPILE_SDK="${ANDROID_COMPILE_SDK:-35}"
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-35.0.0}"
ANDROID_EMULATOR_API="${ANDROID_EMULATOR_API:-34}"
ANDROID_CMDLINE_TOOLS_VERSION="${ANDROID_CMDLINE_TOOLS_VERSION:-11076708}"
INSTALL_GUI="${INSTALL_GUI:-true}"
INSTALL_EMULATOR="${INSTALL_EMULATOR:-$INSTALL_GUI}"
AVD_NAME="${AVD_NAME:-Pixel_6_API_${ANDROID_EMULATOR_API}}"
AVD_DEVICE_PROFILE="${AVD_DEVICE_PROFILE:-pixel_6}"

echo "======================================================="
echo "  🛠️  Provisioning Android Sandbox Environment        "
echo "======================================================="
echo "Configuration:"
echo "  • Compile SDK Platform: android-$ANDROID_COMPILE_SDK"
echo "  • Build-Tools:          $ANDROID_BUILD_TOOLS"
echo "  • GUI / Desktop support: $INSTALL_GUI"
echo "  • Emulator & AVD:        $INSTALL_EMULATOR (API $ANDROID_EMULATOR_API)"
echo "======================================================="

# 1. Verify execution inside container
if [ ! -f /run/host/container-manager ] && [ -z "$CONTAINER_ID" ] && [ ! -f /.dockerenv ]; then
    echo "⚠️  WARNING: It appears you are not inside a Distrobox container."
    echo "   Enter first from the host using:"
    echo "     ./enter.sh android-dev"
    echo ""
    read -rp "Are you sure you want to continue here? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# 2. Install system packages inside container
echo ""
echo "📦 [1/5] Installing base toolchain (JDK 21, utilities)..."
BASE_PACKAGES_FEDORA="java-21-openjdk-devel wget curl unzip git which file tar findutils procps-ng"
EMULATOR_PACKAGES_FEDORA="libglvnd-glx mesa-dri-drivers libX11 libXext libXdamage libXfixes libXcursor libXrandr libxkbcommon libXi libXrender pulseaudio-libs vulkan-loader pciutils xrandr"

BASE_PACKAGES_DEBIAN="openjdk-21-jdk wget curl unzip git file procps"
EMULATOR_PACKAGES_DEBIAN="libgl1-mesa-glx libgl1-mesa-dri libpulse0 libxcursor1 libxcomposite1 libasound2t64 libvulkan1 pciutils"

if command -v dnf >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL="$BASE_PACKAGES_FEDORA"
    if [ "$INSTALL_GUI" = "true" ]; then
        echo "   (Including desktop GUI, Mesa, Vulkan, and audio libraries)"
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $EMULATOR_PACKAGES_FEDORA"
    else
        echo "   (Headless mode: skipping desktop GUI and multimedia libraries)"
    fi
    # shellcheck disable=SC2086
    sudo dnf install -y --skip-unavailable $PACKAGES_TO_INSTALL
elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    PACKAGES_TO_INSTALL="$BASE_PACKAGES_DEBIAN"
    if [ "$INSTALL_GUI" = "true" ]; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $EMULATOR_PACKAGES_DEBIAN"
    fi
    # shellcheck disable=SC2086
    sudo apt-get install -y $PACKAGES_TO_INSTALL
fi

# 3. Configure Android SDK directories in isolated home
echo ""
echo "📁 [2/5] Setting up Android SDK in $HOME/Android/Sdk..."
export ANDROID_HOME="$HOME/Android/Sdk"
mkdir -p "$ANDROID_HOME/cmdline-tools"

# 4. Download official Android Command-Line Tools if not present
CMDLINE_LATEST="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
if [ ! -f "$CMDLINE_LATEST" ]; then
    echo "📥 Downloading official Android Command-Line Tools (v${ANDROID_CMDLINE_TOOLS_VERSION})..."
    CMDLINE_ZIP="/tmp/cmdline-tools.zip"
    curl -Lo "$CMDLINE_ZIP" "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip"
    
    echo "📂 Extracting command-line tools..."
    rm -rf /tmp/cmdline-tools-temp
    unzip -q "$CMDLINE_ZIP" -d /tmp/cmdline-tools-temp
    rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mv /tmp/cmdline-tools-temp/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
    rm -f "$CMDLINE_ZIP"
fi

# 5. Export environment variables for current session and .bashrc
export ANDROID_AVD_HOME="$HOME/.config/.android/avd"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$HOME/.local/bin:$PATH"

if ! grep -q "ANDROID_HOME" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo ""
        echo "# Android SDK Configuration (Distrobox Sandbox)"
        echo "export ANDROID_HOME=\"\$HOME/Android/Sdk\""
        echo "export ANDROID_AVD_HOME=\"\$HOME/.config/.android/avd\""
        echo "export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$HOME/.local/bin:\$PATH\""
        if [ -d "/usr/lib/jvm/java-21-openjdk" ]; then
            echo "export JAVA_HOME=\"/usr/lib/jvm/java-21-openjdk\""
        fi
    } >> "$HOME/.bashrc"
fi


# 6. Accept Android licenses
echo ""
echo "📝 [3/5] Accepting Android SDK licenses..."
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true

# 7. Install core SDK components
echo ""
echo "⬇️  [4/5] Downloading SDK components (platform-tools, platforms;android-${ANDROID_COMPILE_SDK}, build-tools;${ANDROID_BUILD_TOOLS})..."
SDK_COMPONENTS="platform-tools platforms;android-${ANDROID_COMPILE_SDK} build-tools;${ANDROID_BUILD_TOOLS}"
if [ "$INSTALL_EMULATOR" = "true" ]; then
    SDK_COMPONENTS="$SDK_COMPONENTS emulator"
fi
# shellcheck disable=SC2086
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" $SDK_COMPONENTS

# 8. Install emulator system image and create AVD (optional)
if [ "$INSTALL_EMULATOR" = "true" ]; then
    echo ""
    echo "📱 [5/5] Downloading emulator system image (Android $ANDROID_EMULATOR_API Google APIs x86_64)..."
    yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
        "system-images;android-${ANDROID_EMULATOR_API};google_apis;x86_64"

    # Create default AVD if not present
    AVD_MANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
    if ! "$ANDROID_HOME/emulator/emulator" -list-avds 2>/dev/null | grep -q "$AVD_NAME"; then
        echo "📱 Creating virtual device '$AVD_NAME'..."
        echo "no" | "$AVD_MANAGER" create avd -n "$AVD_NAME" -k "system-images;android-${ANDROID_EMULATOR_API};google_apis;x86_64" --device "$AVD_DEVICE_PROFILE" --force
        echo "✅ Virtual device '$AVD_NAME' created."
    fi
else
    echo ""
    echo "📱 [5/5] Skipping emulator system image download (INSTALL_EMULATOR=false)..."
fi

# 9. Install CLI tools from bin/ into ~/.local/bin
if [ -d "$SCRIPT_DIR/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    cp -r "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/"*
fi

chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo ""
echo "======================================================="
echo "  🎉 Sandbox provisioning completed!                   "
echo "======================================================="
echo "Everything is configured in your isolated environment."
echo ""
echo "Available commands in this sandbox:"
echo "  • Version manager:      change_version [list|remote|<API>]"
echo "  • Workspace directory:  cd $WORKSPACE_DIR"
if [ "$INSTALL_EMULATOR" = "true" ]; then
    echo "  • Launch emulator:      emulator -avd $AVD_NAME"
else
    echo "  • Emulator:             Not installed (INSTALL_EMULATOR=false)"
fi
echo "======================================================="
