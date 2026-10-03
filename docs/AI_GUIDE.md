# Distrobox Master Guide for AI Agents and Developers

This guide defines the technical, operational, and architectural standards for using isolated sandboxes with **Distrobox** and **Podman** within this development workstation (`~/Workspace`).

---

## 1. System Architecture & Philosophy

The development environment is deployed on **Fedora Linux**, using centralized sandbox definitions from [`distrobox-configs`](../README.md).

```text
                                HOST SYSTEM (Fedora Linux)
                  ┌────────────────────────────────────────────────────────┐
                  │ • Podman 5.8+ • Distrobox 1.8+                         │
                  │ • Shared workspace: ~/Workspace                        │
                  │ • Shared network namespace: loopback (localhost)       │
                  └───────────────┬────────────────────────┬───────────────┘
                                  │                        │
         ┌────────────────────────┴────────┐      ┌────────┴────────────────────────┐
         │                                 │      │                                 │
         ▼                                 ▼      ▼                                 ▼
┌──────────────────┐             ┌──────────────────┐             ┌──────────────────┐
│   node-dev       │             │   python-dev     │             │   java-dev       │
├──────────────────┤             ├──────────────────┤             ├──────────────────┤
│ • fnm + Node 24  │             │ • uv + Py 3.13   │             │ • SDKMAN!        │
│ • pnpm / bun     │             │ • ruff, mypy     │             │ • Java 21, Gradle│
│ • React, Vite    │             │ • C/C++ Headers  │             │ • GraalVM, GUI   │
│ 📁 Isolated Home:│             │ 📁 Isolated Home:│             │ 📁 Isolated Home:│
│   .../node-dev   │             │   .../python-dev │             │   .../java-dev   │
└────────┬─────────┘             └────────┬─────────┘             └────────┬─────────┘
         │                                │                                │
         └─────────────────► 📂 $HOME/Workspace ◄──────────────────────────┘
                             (Identical bidirectional rw mount)
```

### Core Architectural Principles:
1. **Total `$HOME` Isolation:**
   - Each sandbox stores its tool configurations, SDKs, and caches in a dedicated host path:
     `$HOME/.local/share/distrobox-homes/<container-name>/`
   - **Benefit:** Tool caches (`~/.npm`, `~/.pnpm-store`, `~/.cache/uv`, `~/.sdkman`, `~/.android`) never pollute the host system or interfere across containers.
2. **Transparent Workspace Mount (`~/Workspace`):**
   - The host directory `$HOME/Workspace` is mounted with full read-write permissions at the exact same absolute path inside each sandbox:
     `$HOME/Workspace:$HOME/Workspace:rw`
   - **Benefit:** No code cloning, synchronization scripts, or file transfers are required between sandboxes.
3. **Native Host Network Mapping (`--net=host`):**
   - Distrobox shares the host's network stack. Any network port opened by a service (e.g., FastAPI on `8080` in `python-dev`) is accessible immediately at `http://localhost:8080` on the host and inside `node-dev`.
4. **Hardware Acceleration Passthrough (`/dev/dri` and `/dev/kvm`):**
   - Enables GPU-accelerated rendering for desktop GUIs (JavaFX, Compose Desktop) and native KVM virtualization for mobile emulators (Android AVD).
5. **Permissions & Security:**
   - The user inside the sandbox matches the host user (same UID, GID, and username).
   - Passwordless `sudo` is configured inside containers to install Fedora system packages via `sudo dnf install -y <package>`.

---

## 2. Sandbox Catalog & Responsibilities

| Container | Base Image | Toolchains & Runtimes | Primary Use Cases |
| :--- | :--- | :--- | :--- |
| **`node-dev`** | `fedora-toolbox` | • `fnm` (Fast Node Manager)<br>• Node.js 24 Active LTS (default)<br>• `pnpm`, `npm`, `yarn`, `bun`<br>• Native headers (`node-gyp`)<br>• Headless browser deps (Vitest, Playwright) | • Frontend SPA/SSR (React, Vite, Next.js)<br>• Web tools, TypeScript/JavaScript scripts |
| **`python-dev`** | `fedora-toolbox` | • Astral `uv` (package & venv manager)<br>• Python 3.13 (default), 3.14<br>• `ruff`, `mypy`, `pytest`, `pre-commit`<br>• C/C++ toolchain (`gcc`, `openssl-devel`, etc.) | • Backend services (FastAPI, Django)<br>• AI pipelines & agent runtimes (LangGraph, PyTorch)<br>• Automation & data science |
| **`java-dev`** | `fedora-toolbox` | • SDKMAN!<br>• Eclipse Temurin OpenJDK 21 LTS<br>• Gradle, Apache Maven, Kotlin<br>• GraalVM Native Image toolchain<br>• GUI support (X11, GTK3, Mesa) | • JVM backend services (Spring Boot, Quarkus)<br>• Desktop apps (Compose Desktop, JavaFX)<br>• Native binary compilation |
| **`android-dev`** | `fedora-toolbox` | • OpenJDK 21<br>• Android SDK Command-line Tools (`sdkmanager`, `adb`)<br>• Platform 35 & build-tools<br>• x86_64 emulator with KVM acceleration | • Android mobile application development<br>• Mobile emulator testing<br>• APK & AAB packaging |

---

## 3. Host Operations & Non-Interactive Commands

### Creation & Assembly:
```bash
# Create a single container:
cd $HOME/Workspace/distrobox-configs
./create.sh node-dev
./create.sh python-dev

# Or assemble all containers declared in distrobox.ini:
distrobox assemble create --file $HOME/Workspace/distrobox-configs/distrobox.ini
```

### Non-Interactive Programmatic Execution for AI Agents:
AI agents must execute commands using `bash -lc` to guarantee that the container's environment variables, PATH, and user profiles are initialized:

```bash
distrobox enter <container-name> -- bash -lc "<commands>"
```

---

## 4. Unified Version Manager (`change_version`)

Every sandbox includes the `change_version` utility located in `$HOME/.local/bin/change_version`.

```bash
# Display current runtime version and active tools:
distrobox enter <container> -- bash -lc "change_version"

# List locally installed versions (works offline):
distrobox enter <container> -- bash -lc "change_version list"

# List recommended remote versions available upstream:
distrobox enter <container> -- bash -lc "change_version remote"

# Switch or install a specific runtime version:
distrobox enter node-dev -- bash -lc "change_version 24"
distrobox enter python-dev -- bash -lc "change_version 3.14"
distrobox enter java-dev -- bash -lc "change_version 17"
```

---

## 5. Technical Justification & Anti-Downgrade Policies

### Mandatory Technical Justification:
Any software installation or environment change must document:
1. **Why it is needed:** The technical root cause (e.g., missing header, build failure).
2. **What for:** The specific functional requirement it unlocks.

### Strict Anti-Downgrade Policy:
1. Always preserve the latest stable runtime versions (Node 24 LTS, Python 3.13+, OpenJDK 21).
2. Never arbitrarily downgrade versions unless mandated by a project specification file (`.nvmrc`, `.python-version`).
3. Resolve third-party library conflicts by updating dependencies rather than degrading the sandbox base image.

---

## 6. Automated Management Script: `ensure_distrobox_env.sh`

Located at [`distrobox-configs/scripts/ensure_distrobox_env.sh`](../scripts/ensure_distrobox_env.sh):

```bash
# Inspect container health and project alignment:
bash $HOME/Workspace/distrobox-configs/scripts/ensure_distrobox_env.sh \
  -c python-dev \
  -p "$HOME/Workspace/tale-forge" \
  -a check

# Install a system package with justification:
bash $HOME/Workspace/distrobox-configs/scripts/ensure_distrobox_env.sh \
  -c python-dev \
  -a install \
  --component system-pkg \
  --version "libpq-devel" \
  --why "Required pg_config headers for psycopg2 compilation" \
  --for-what "PostgreSQL database connection"

# Verify sandbox health (Smoke Tests):
bash $HOME/Workspace/distrobox-configs/scripts/ensure_distrobox_env.sh \
  -c node-dev \
  -a verify
```
