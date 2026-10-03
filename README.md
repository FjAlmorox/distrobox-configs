# 📦 Distrobox Configs - Isolated Development Environments

[![CI & Security Audit](https://github.com/FjAlmorox/distrobox-configs/actions/workflows/ci.yml/badge.svg)](https://github.com/FjAlmorox/distrobox-configs/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

Central repository to manage development environments and containers on **Fedora** using **Distrobox** and **Podman**.


---

## 🏛️ Philosophy and Container Standards

Each environment configured in this repository adheres to the following directives:

1. **Total `$HOME` Isolation**:
   Each container maintains its own isolated home directory at:
   `~/.local/share/distrobox-homes/<environment-name>`
   This prevents tool configurations, caches, or SDKs (such as SDKMAN, Gradle, or Android SDK) from polluting or conflicting with the host system or other containers.
2. **Shared Workspace**:
   The entire host `$HOME/Workspace` directory is bidirectionally mounted into the container at the identical absolute path, enabling seamless work across repositories without file duplication.
3. **Hardware Acceleration (GPU & KVM)**:
   Direct passthrough of `/dev/dri` (graphical acceleration for emulators and desktop GUIs) and `/dev/kvm` (hardware virtualization).
4. **Strict Boundary between Host and Container**:
   * **Root Level (Host)**: Centralized orchestration scripts (`create.sh`, `enter.sh`), declarative manifest (`distrobox.ini`), and Git configuration files (`.gitignore`, `.gitattributes`, `.editorconfig`).
   * **Subdirectory Level (Container)**: Everything belonging to that specific sandbox (`setup.sh`, `bin/`, `README.md`).

---

## 📁 Repository Structure

```text
distrobox-configs/
├── .agents/                    # Modular skills and AI agent knowledge base
│   └── skills/                 # Portable, task-specific runbooks (agentskills.io)
├── .editorconfig               # Indentation, UTF-8, and LF normalization across editors
├── .env.example                # Public and generic environment variables template
├── .gitattributes              # Strict protection: enforces LF for scripts and CLI tools
├── .github/
│   └── workflows/
│       └── ci.yml              # CI/CD: Automated linting, syntax, and secret scanning
├── .githooks/                  # Versioned Git hooks in the repository
│   ├── pre-commit              # Local scanner: blocks personal data and secret leaks on commit
│   └── pre-push                # Global auditor: verifies security and sandbox structure on push
├── tests/                      # Automated validation and structural auditing
│   └── validate-sandboxes.sh   # Static structural, permission, syntax, and sandbox auditor

├── .gitignore                  # Exclusions for secrets, temporary files, IDEs, and homes
├── AGENTS.md                   # Operational guidelines and protocol for AI Agents
├── LICENSE                     # MIT Open Source License
├── README.md                   # General documentation and environment catalog
├── create.sh                   # [Host] Interactive/CLI script to create sandboxes
├── distrobox.ini               # [Host] Declarative manifest (single source of truth)
├── enter.sh                    # [Host] Interactive/CLI script to enter sandboxes
│
├── android-dev/                # [Environment] Android Development
│   ├── setup.sh                # Internal bootstrap (run once inside sandbox)
│   ├── bin/                    # CLI commands installed to ~/.local/bin/
│   │   └── change_version      # SDK and emulator version manager
│   └── README.md               # Android technical documentation
│
├── java-dev/                   # [Environment] Java / Kotlin / JVM Development
│   ├── setup.sh                # Internal bootstrap (run once inside sandbox)
│   ├── bin/                    # CLI commands installed to ~/.local/bin/
│   │   └── change_version      # JDK, GraalVM, and SDK version manager
│   └── README.md               # Java/JVM technical documentation
│
├── python-dev/                 # [Environment] Python Development (uv, modern Python runtimes)
│   ├── setup.sh                # Internal bootstrap (run once inside sandbox)
│   ├── bin/                    # CLI commands installed to ~/.local/bin/
│   │   └── change_version      # Python runtime and version manager
│   └── README.md               # Python technical documentation
│
└── node-dev/                   # [Environment] Node.js & Frontend Development (fnm, pnpm, bun)
    ├── setup.sh                # Internal bootstrap (run once inside sandbox)
    ├── bin/                    # CLI commands installed to ~/.local/bin/
    │   └── change_version      # Node.js runtime and version manager
    └── README.md               # Node.js & Frontend technical documentation
```

---

## 🛡️ Version Control, Security, and Privacy

This repository implements a **defense-in-depth** strategy to ensure that no personal data, private paths, or secrets can ever be published:

### 1. Automated Pre-Commit Scanner (`.githooks/pre-commit`)
Git automatically invokes this hook before accepting any `git commit`:
* **Blocks personal absolute paths**: Detects and rejects paths matching `/home/<user>/...`, enforcing portable variables (`${HOME}` or `$HOME`).
* **Blocks host local username**: Dynamically resolves the developer's host username and prevents it from leaking into scripts or documentation.
* **Blocks cryptographic keys and certificates**: Rejects RSA, OpenSSH, PEM private keys, and certificates.
* **Blocks tokens and API keys**: Detects patterns for GitHub tokens, AWS access keys, and Bearer tokens.
* **Blocks plaintext credentials**: Rejects password or secret assignments in code.

### 2. Full Pre-Push Audit (`.githooks/pre-push`)
Git automatically invokes this hook before pushing changes to any remote repository (`git push`):
* Executes the security scanner in global mode (`--all`) across all tracked files.
* Executes `./tests/validate-sandboxes.sh` to guarantee all sandboxes are structurally sound, declared in `distrobox.ini`, have executable permissions (`100755`), and pass syntax validation.
* Guarantees that no prior commit or unnoticed file leaks sensitive data before reaching the remote.
* **Strict Bypass Prohibition**: Using the `--no-verify` flag on commits or pushes is strictly prohibited.

**To enable the hooks on any newly cloned machine:**
```bash
git config core.hooksPath .githooks
```
*(Pre-configured by default in this workspace)*.

**To run manual validation at any time:**
```bash
# Validate staged changes for privacy and secret leaks:
./.githooks/pre-commit

# Validate sandbox structures, permissions, and bash syntax:
./tests/validate-sandboxes.sh

# Validate the entire repository (simulating pre-push):
./.githooks/pre-push
```

### 3. Continuous Integration & Quality Gate (`.github/workflows/ci.yml`)
Every push to `main` and every pull request targeting `main` is automatically verified by a lightweight, resource-optimized GitHub Actions workflow running on standard `ubuntu-latest`:
* **Zero-Cost, Minimal Footprint**: Runs in a single unified job without container overhead, completing in under 20 seconds.
* **Trigger Policy**: Only runs on `main` and Pull Requests. Developers can push to working branches (e.g. `feature/<name>`) without consuming CI runner time until ready to merge.
* **Concurrency Auto-Cancellation**: Cancels obsolete in-progress runs automatically on new pushes to prevent wasted compute.
* **Pipeline Checks**:
  * **Dynamic Sandbox & Script Validation**: Runs `./tests/validate-sandboxes.sh --strict` (validates all existing and newly added sandboxes dynamically, checking permissions, LF line endings, syntax `bash -n`, and static linting via `shellcheck`).
  * **Security & Privacy Audit**: Executes `./.githooks/pre-commit --all`.
  * **Gitleaks Secret Scanning**: Analyzes git history for potential secrets and credentials.
* **Workflow State Control**: The automated CI workflow can be paused or resumed anytime using the GitHub CLI:
  ```bash
  gh workflow disable ci.yml  # Pause automated CI runs
  gh workflow enable ci.yml   # Resume automated CI runs
  ```

> [!TIP]
> **Recommended Server-Side Setting**: For total defense-in-depth, enable **Secret scanning** and **Push protection** in your GitHub repository under *Settings* ➔ *Code security and analysis*. This blocks any push containing known tokens directly on GitHub's servers before the commits are accepted.


### 4. Strict Exclusion Shielding (`.gitignore`)
* **Secrets and Environments**: Blocks `.env`, `*.env`, certificates, private keys (`*.key`, `*.pem`, `id_rsa*`, etc.), and Android keystores (`*.keystore`, `*.jks`, `keystore.properties`, `local.properties`).
* **Safe Local Overrides**: Enables developers to maintain private local overrides (`distrobox.local.ini`, `*.local`, `local/`) without any risk of committing them.
* **Distrobox Isolation**: Prevents accidental tracking of isolated home directories (`distrobox-homes/`).

### 5. Normalization and Execution Permissions (`.gitattributes` & `.editorconfig`)
* **Enforce Unix `LF` Line Endings**: Prevents Windows checkouts or edits from corrupting shell scripts (`*.sh`, `create.sh`, `enter.sh`, `*/bin/*`, `*-dev/bin/*`).
* **Preserve Executable Permissions (`100755`)**: Git explicitly tracks execution bits so all scripts remain executable upon checkout.

### 6. Pull Request Standards & Template (`.github/pull_request_template.md`)
All contributions and new environment branches submitted to `main` must use the repository's standardized Pull Request template:
* **Environment Scope**: Declares container name, base image, pre-installed toolchains, and CLI commands.
* **Testing Steps**: Documents manual verification commands (`./create.sh`, `./enter.sh`).
* **Interactive DoD Checklist**: Requires interactive confirmation of all Definition of Done invariants (clean static checks, executable bits, zero privacy leaks) before merge.

### 7. Hierarchical Environment Customization (`.env.example`)
You can customize container base versions, storage paths, and tooling toggles locally without altering version-controlled files:
1. Copy [`.env.example`](./.env.example) to `.env` in the repository root:
   ```bash
   cp .env.example .env
   ```
2. Configure desired variables (e.g. `FEDORA_VERSION=44`, `INSTALL_GUI=false`, `INSTALL_EMULATOR=false`).
Both [`create.sh`](./create.sh), [`enter.sh`](./enter.sh), and internal `setup.sh` scripts automatically detect and apply settings from `.env`.


---

## 🚀 Available Environments

| Environment | Directory | Base Image | Focus | Documentation |
| :--- | :--- | :--- | :--- | :--- |
| **`android-dev`** | [`./android-dev/`](./android-dev/) | `fedora-toolbox:44` | Android SDK, x86_64 Emulator, AVDs, ADB, OpenJDK 21 | [View details](./android-dev/README.md) |
| **`java-dev`** | [`./java-dev/`](./java-dev/) | `fedora-toolbox:44` | Java 21, Kotlin, SDKMAN, Gradle, Maven, GraalVM tools, Desktop GUI | [View details](./java-dev/README.md) |
| **`python-dev`** | [`./python-dev/`](./python-dev/) | `fedora-toolbox:44` | Astral `uv`, Python 3.13/3.14, C build headers, Ruff, Mypy, Pytest | [View details](./python-dev/README.md) |
| **`node-dev`** | [`./node-dev/`](./node-dev/) | `fedora-toolbox:44` | `fnm`, Node 24 LTS, pnpm, bun, React/Angular, Vitest/Playwright | [View details](./node-dev/README.md) |

---

## 🎛️ Host Operations (`create.sh` & `enter.sh`)

Root-level scripts manage any repository environment in a unified way:

```bash
# 1. Create a specific container:
./create.sh android-dev
./create.sh java-dev
./create.sh python-dev
./create.sh node-dev

# Or run without arguments for an interactive menu:
./create.sh

# 2. Enter a container (positions you directly in your Workspace):
./enter.sh android-dev
./enter.sh java-dev
./enter.sh python-dev
./enter.sh node-dev

# Or interactive menu:
./enter.sh
```

---

## 📋 Global Manifest Management (`distrobox.ini`)

You can create or remove all containers simultaneously using the central manifest [`distrobox.ini`](./distrobox.ini):

```bash
# Create all containers defined in the manifest
distrobox assemble create --file ./distrobox.ini

# Remove all containers
distrobox assemble rm --file ./distrobox.ini
```

---

## 🛠️ General Distrobox Commands

### Container Lifecycle
```bash
# List all containers and their current status
distrobox list

# Enter a container directly
distrobox enter <container-name>

# Stop a container to release RAM and CPU resources
distrobox stop <container-name>

# Remove a container (preserves isolated home and workspace intact)
distrobox rm <container-name>

# Force removal of a running container
distrobox rm -f <container-name>
```

### Host System Integration (`distrobox-export`)
Distrobox allows exporting tools and GUI apps from containers directly into the host system without manual terminal access:

```bash
# 1. Export a GUI application to the host application menu:
distrobox-export --app <app_name>

# 2. Export a CLI binary to host terminal execution:
distrobox-export --bin /path/to/binary --export-path ~/.local/bin

# 3. Delete an exported binary or app:
distrobox-export --delete --app <app_name>
distrobox-export --delete --bin /path/to/binary --export-path ~/.local/bin
```

### Accessing Host Files from within Containers
If you occasionally need to access host files outside your Workspace or isolated home, the host filesystem is mounted in read/write mode at:
```bash
/run/host
```
*(For example, `/run/host/etc/` or `/run/host/home/$USER/`)*.

---

## 🔄 Version Management Standard (`change_version`)

To maintain a consistent experience across containers, any sandbox managing multiple SDK or runtime versions implements **`change_version`**:

* Automatically copied to `$HOME/.local/bin/change_version` during `setup.sh`.
* Directly executable from any directory inside the container without paths or prefixes.

### Unified Command Contract

| Command | Description |
| :--- | :--- |
| `change_version` *(or `status`)* | Shows current active version and complementary tools status. |
| `change_version list` *(or `-l`)* | Lists versions installed locally in the container. |
| `change_version remote` *(or `-r`)* | Lists recommended versions available online. |
| `change_version install <ver> [opts]` | Downloads and installs a version. |
| `change_version set <ver> [opts]` | Activates specified version (downloads if missing). |
| `change_version <ver> [opts]` | Quick shortcut equivalent to `change_version set <ver>`. |

### Behavior by Sandbox

* **In `android-dev`**:
  * Manages Android SDK Platform versions (e.g. `34`, `35`) and matching Build-tools.
  * Supports `-e` / `--with-emulator` flag to download x86_64 system images and create AVDs.
* **In `java-dev`**:
  * Manages Java versions (e.g. `17`, `21`, `25`) powered by SDKMAN.
  * Defaults to **Eclipse Temurin LTS**. Use `-g` / `--graalvm` for **GraalVM CE**.
  * Use `-s` / `--session` to switch versions for current terminal session only (`sdk use`).
  * Displays cross-tool status for Gradle, Maven, Kotlin, and `.sdkmanrc` files.
* **In `python-dev`**:
  * Manages Python runtime versions (e.g. `3.13`, `3.14`, `3.13t`, `pypy3.10`) powered by Astral `uv`.
  * Installs on demand and switches global default symlinks in `~/.local/bin/`.
  * Supports `-p` / `--project` flag to pin Python versions to local `.python-version` files.
  * Displays cross-tool status for `uv`, active virtualenvs, `ruff`, `mypy`, `pytest`, and `ipython`.
* **In `node-dev`**:
  * Manages Node.js versions (e.g. `24`, `22`, `26`) powered by `fnm` (Fast Node Manager).
  * Automatically applies `.node-version` and `.nvmrc` files on directory navigation.
  * Supports `-s` / `--session` flag to switch versions for current shell session only.
  * Displays cross-tool status for `pnpm`, `npm`, `yarn`, `bun`, and `package.json` detection.



---

## ➕ How to Add a New Environment

Thanks to the centralized host architecture, adding a new environment (e.g. `python-dev`, `kubernetes`, `ubuntu-test`, etc.) requires only 4 steps:

1. **Add entry** to [`distrobox.ini`](./distrobox.ini).
2. **Create directory** named after the container (`<name>/`):
   * `setup.sh`: Unattended provisioning script (packages and dependencies).
   * `bin/`: *(Optional)* CLI tools copied to `$HOME/.local/bin/` (e.g. `change_version`).
   * `README.md`: Environment-specific documentation.
3. **Link new environment** in the table of this `README.md`.
4. **Verify and register in Git**:
   * Run automated audit: `./tests/validate-sandboxes.sh`
   * Add to version control: `git add <name>/ distrobox.ini README.md`
   * Confirm status with `git status`.

> *Note: You do NOT need to create any `create.sh` or `enter.sh` scripts inside environment folders; root orchestration scripts manage any environment automatically.*
