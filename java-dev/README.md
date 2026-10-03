# ☕ Environment: Java / Kotlin / JVM (`java-dev`)

Isolated Distrobox container for modern development in the JVM ecosystem: **Java**, **Kotlin**, **Gradle**, **Maven**, native compilation (**GraalVM Native Image**), and desktop GUI applications (**Compose Multiplatform Desktop**, **JavaFX**, **Swing / FlatLaf**).

---

## 📁 Environment Files

* **[`setup.sh`](./setup.sh)**: Internal sandbox provisioning script (run once inside the container).
* **[`bin/change_version`](./bin/change_version)**: Unified version manager (automatically installed to `~/.local/bin/change_version`).

---

## 🚀 Getting Started

### 1. Create the container (from the Host at the repo root)
```bash
./create.sh java-dev
```
*(Or via the interactive menu: `./create.sh`)*

### 2. Enter the container (from the Host)
```bash
./enter.sh java-dev
```

### 3. Provision tools (ONCE only, INSIDE the container)
```bash
bash $HOME/Workspace/distrobox-configs/java-dev/setup.sh
```

---

## 📦 Installed Components

* **SDKMAN!**: Software Development Kit Manager for the JVM ecosystem.
* **Java**: Eclipse Temurin OpenJDK 21 LTS configured as default.
* **Build Tools**: Gradle and Apache Maven installed via SDKMAN.
* **Kotlin**: Kotlin CLI (`kotlinc`) and Kotlin toolchain.
* **Native Compilation (GraalVM `native-image`)**: `gcc`, `gcc-c++`, `glibc-devel`, `zlib-devel`, `libstdc++-devel` pre-installed for native builds (Quarkus, Spring Boot Native, Micronaut, or native Compose binaries).
* **Desktop GUI Support**:
  * **Rendering & 3D**: Mesa DRI drivers, OpenGL (`libglvnd-glx`), Vulkan loader, and GPU acceleration (`/dev/dri`).
  * **X11 / GTK**: GTK3, glib2, libX11, libXtst, libXrender, libXcursor, libXrandr, libXi.
  * **System Typography**: `fontconfig`, `freetype`, `dejavu-sans-fonts`, `google-noto-sans-fonts` (essential for Skiko in Compose Desktop and JavaFX to properly render fonts).
  * **Audio**: ALSA and PulseAudio / PipeWire support.

---

## 🛠️ Useful Commands

### Unified version manager (`change_version`)
The script is copied to `$HOME/.local/bin/change_version` and is directly available in your terminal:

```bash
# 1. View current status (active Java, path, Gradle, Maven, Kotlin, and .sdkmanrc)
change_version

# 2. List locally installed versions
change_version list

# 3. List recommended versions online (Temurin and GraalVM)
change_version remote

# 4. Install or switch to Java 17 LTS (automatically resolves to Temurin)
change_version 17

# 5. Install or switch to GraalVM CE 21 to build native binaries
change_version 21 --graalvm

# 6. Switch version for current terminal session only (without changing default)
change_version 17 --session
```

### Direct SDKMAN advanced usage
If you need additional providers or packages from the SDKMAN catalog:
```bash
sdk list java                  # Full catalog of providers and vendors
sdk install java <identifier>  # Install an arbitrary candidate identifier
sdk env init                   # Generate .sdkmanrc for the current directory
```

### Running GUI applications with Compose Desktop / JavaFX
Thanks to X11 socket mapping (`/tmp/.X11-unix`) and GPU acceleration, you can compile and run desktop GUI applications directly from inside the container:
```bash
# Example with a Gradle project
./gradlew run
```
The window will instantly display on your host desktop.

---

## ⚙️ Configuration and Customization

### Local Customization via `.env`
You can configure sandbox defaults before running `setup.sh` via `.env` in the repository root:

```bash
# Set to 'false' for an ultra-lightweight, headless backend/CLI sandbox (omits GTK3, X11, fonts, audio)
INSTALL_GUI=false

# Default Java LTS version installed via SDKMAN! (default: 21)
JAVA_DEFAULT_VERSION=21

# Enable or disable complementary build tools
INSTALL_GRADLE=true
INSTALL_MAVEN=true
INSTALL_KOTLIN=true
```

### Paths and Exported Environment
* **Isolated Home**: `~/.local/share/distrobox-homes/java-dev`
* **SDKMAN**: `$HOME/.sdkman`
* **Exported variables in `.bashrc`**:
  * `SDKMAN_DIR=$HOME/.sdkman`
  * `JAVA_HOME=$HOME/.sdkman/candidates/java/current`
  * `PATH` includes SDKMAN binaries and `$HOME/.local/bin`.
