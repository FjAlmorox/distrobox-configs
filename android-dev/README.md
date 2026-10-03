# 🤖 Environment: Android (`android-dev`)

Isolated Distrobox container for Android development with hardware emulation, Android SDK Command-line Tools, and OpenJDK 21.

---

## 📁 Environment Files

* **[`setup.sh`](./setup.sh)**: Internal sandbox provisioning script (run once inside the container).
* **[`bin/change_version`](./bin/change_version)**: Unified version manager (automatically installed to `~/.local/bin/change_version`).

---

## 🚀 Getting Started

### 1. Create the container (from the Host at the repo root)
```bash
./create.sh android-dev
```
*(Or via the interactive menu: `./create.sh`)*

### 2. Enter the container (from the Host)
```bash
./enter.sh android-dev
```

### 3. Provision tools (ONCE only, INSIDE the container)
```bash
bash $HOME/Workspace/distrobox-configs/android-dev/setup.sh
```

---

## 📦 Installed Components

* **Java**: OpenJDK 21 (`java-21-openjdk-devel`).
* **Android SDK**:
  * Official Command-line Tools (`sdkmanager`, `avdmanager`, `adb`).
  * Android SDK Platform 35 and Build-tools 35.0.0.
  * Official x86_64 Emulator with KVM acceleration.
  * Pre-configured virtual device: `Pixel_6_API_34` (Android 34 Google APIs x86_64).
* **Graphics and Multimedia Dependencies**:
  * Mesa DRI drivers, OpenGL, Vulkan loader.
  * X11 and PulseAudio libraries for desktop audio and window rendering.

---

## 🛠️ Useful Commands

### Unified version manager (`change_version`)
The script is copied to `$HOME/.local/bin/change_version` and is directly available in your terminal:

```bash
# 1. View current status (platforms, build-tools, emulators, and active Java)
change_version

# 2. List locally installed versions
change_version list

# 3. List main versions available online
change_version remote

# 4. Install or switch to Android 14 (API 34)
change_version 34

# 5. Install Android 15 (API 35) and create its emulator/AVD
change_version 35 --with-emulator
```

### Working with Android projects
```bash
cd $HOME/Workspace/your_android_project

# Compile Debug APK
./gradlew assembleDebug

# Launch emulator (desktop GUI window)
emulator -avd Pixel_6_API_34 &

# Install and run on the emulator
./gradlew installDebug
```

---

## ⚙️ Configuration and Customization

### Local Customization via `.env`
You can configure sandbox defaults before running `setup.sh` via `.env` in the repository root:

```bash
# Master toggle: set to 'false' for an ultra-fast, headless build container
# (omits Mesa, X11, Vulkan, audio libraries, and the 1.5 GB emulator)
INSTALL_GUI=false

# Granular emulator override (defaults to INSTALL_GUI if omitted)
# Set to 'false' if you want GUI libraries but do NOT want the mobile emulator
# INSTALL_EMULATOR=false

# Target compile SDK and build-tools
ANDROID_COMPILE_SDK=35
ANDROID_BUILD_TOOLS="35.0.0"

# Emulator system image API level
ANDROID_EMULATOR_API=34
```

### Paths and Exported Environment
* **Isolated Home**: `~/.local/share/distrobox-homes/android-dev`
* **Android SDK**: `$HOME/Android/Sdk`
* **Exported variables in `.bashrc`**:
  * `ANDROID_HOME=$HOME/Android/Sdk`
  * `JAVA_HOME=/usr/lib/jvm/java-21-openjdk`
  * `PATH` includes: `cmdline-tools`, `platform-tools`, `emulator`, `~/.local/bin`.
