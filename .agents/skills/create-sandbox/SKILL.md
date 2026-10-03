---
name: create-sandbox
description: Comprehensive 7-phase protocol and runbook for creating, provisioning, verifying, and integrating new containerized development environments in this repository.
---

# 📦 Skill: Create Sandbox Environment

This guide defines the mandatory 7-phase process that any AI agent must strictly follow when asked to design, build, provision, test, or integrate a new Distrobox environment.

---

## 📋 The 7-Phase Protocol

### Phase 1: Requirements Analysis and Interview (MANDATORY)
**NEVER generate code blindly.** Before creating any files, conduct a structured, technically grounded interview to clarify and optimize the environment scope.

#### 1. Mandatory Pre-Interview Research (Live Verification)
* **Verify Upstream Real-Time Data**: The agent MUST use web search or official documentation to check current stable, active LTS, and legacy versions. **Never rely on internal memory or outdated defaults.**
* **Identify Modern Tooling**: Investigate modern package and version managers (e.g., `uv` vs `pyenv` in Python, `fnm`/`pnpm` vs `nvm` in Node, `rustup` in Rust, `sdkman` in Java).

#### 2. Architecture & Scope Optimization
Actively guide the user to refine and optimize the container scope for maximum efficiency, fast provisioning, and zero unnecessary bloat:
* **Scope Definition**: Clarify if the sandbox is **lean/specialized** (minimal dependencies, rapid spin-up) or **generalist/battery-included** (full developer toolchain, compilers, native C headers).
* **Container Name**: Kebab-case identifier matching the purpose, stack, or distro (e.g. `python-dev`, `rust-dev` for development environments, or `kubernetes`, `ubuntu-test`, `ansible-lab` for tools and testbeds). No rigid suffix required.
* **Base Image**: `${DISTROBOX_BASE_IMAGE:-registry.fedoraproject.org/fedora-toolbox:${FEDORA_VERSION:-44}}` (default) or a specific distribution if technically required.
* **Version Management**: System packages vs dedicated runtime manager (`change_version` integration).
* **Initial Default Version**: Latest stable vs current LTS.
* **Compilation Toolchain**: Native compilation dependencies (`gcc`, `gcc-c++`, `clang`, `glibc-devel`, `make`) only if required for native extensions or compiled languages.
* **GUI & Multimedia Support**: Headless CLI vs desktop GUI (X11, Wayland, OpenGL, Vulkan, audio) using the Conditional GUI Pattern (`INSTALL_GUI`).
* **Additional System Libraries**: SSL (`openssl-devel`), compression (`zlib-devel`), databases (`sqlite-devel`, `libpq-devel`), etc.

#### 3. Presentation Standards
* **Always Present Options**: Clearly lay out the viable choices for runtimes, package managers, and toolchains.
* **Mark Recommended Choice**: Always explicitly prefix the top option with `(Recommended)` and provide a **reasoned technical justification** explaining *why* it is optimal for container performance, developer ergonomics, and repository consistency.
* **Interactive Elicitation**: Formulate questions clearly so the user can easily choose or refine their preferences.

---

### Phase 2: Feature Branch Initialization (MANDATORY BEFORE ANY FILE EDIT)
**NEVER modify repository files or manifests directly on `main`.**
Once requirements are agreed upon with the user, initialize a dedicated Git feature branch before writing or editing any file:

```bash
# 1. Ensure main is clean
git status

# 2. Create and switch to feature branch
git checkout -b feature/<name>
```

---

### Phase 3: Manifest Declaration
Add the new container section to [`distrobox.ini`](../../distrobox.ini) complying with standard parameterized defaults:

```ini
[<name>]
image="${DISTROBOX_BASE_IMAGE:-registry.fedoraproject.org/fedora-toolbox:${FEDORA_VERSION:-44}}"
home="${DISTROBOX_HOMES_DIR:-${HOME}/.local/share/distrobox-homes}/<name>"
volume="${WORKSPACE_DIR:-${HOME}/Workspace}:${WORKSPACE_DIR:-${HOME}/Workspace}:rw"
additional_flags="${DISTROBOX_ADDITIONAL_FLAGS:---device /dev/kvm --device /dev/dri}"
init=false
nvidia=${DISTROBOX_NVIDIA:-0}
pull=${DISTROBOX_PULL:-1}
root=false
```

---

### Phase 4: Environment Directory Creation (`<name>/`)
Generate the modular subfolder structure:

```text
<name>/
├── setup.sh            # Internal container provisioning script
├── bin/
│   └── change_version  # Unified runtime version manager (if multi-version runtime)
└── README.md           # Sandbox-specific technical documentation
```

#### 1. `setup.sh` Requirements
* **Container check**: Verify execution inside container (`/run/host/container-manager` or `CONTAINER_ID`).
* **Local `.env` loading**: Check for and source `$WORKSPACE_DIR/distrobox-configs/.env` if present.
* **Package installation**: Use `sudo dnf install -y --skip-unavailable ...` (fallback to `apt-get` if Debian/Ubuntu).
* **Conditional GUI / Emulator Pattern (Unified Standard)**:
  If the environment supports desktop interfaces (JavaFX, Qt, GTK), emulators, or multimedia:
  1. Declare the unified master toggle: `INSTALL_GUI="${INSTALL_GUI:-true}"` (or `false` if headless by default).
  2. If the environment provides an emulator, inherit from the master toggle: `INSTALL_EMULATOR="${INSTALL_EMULATOR:-$INSTALL_GUI}"`.
  3. When `INSTALL_GUI=false`, condition **all** related layers:
     * **System packages**: Skip Mesa DRI, Vulkan loader, X11, Wayland, GTK, desktop fonts, and audio libraries.
     * **SDK / Tooling components**: Skip emulator packages, system images, or virtual device (AVD) creation.
  4. The headless/CLI fallback MUST remain minimal, fast (< 30s setup), and strictly focused on compiler/runtime tools.
* **Command installation from `bin/`**:
  ```bash
  if [ -d "$SCRIPT_DIR/bin" ]; then
      mkdir -p "$HOME/.local/bin"
      cp -r "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/"
      chmod +x "$HOME/.local/bin/"*
  fi
  ```
* **Persistent environment variables**: Append required paths and exports to `$HOME/.bashrc` (including `$HOME/.local/bin` in `$PATH`).
* **Non-interactive execution**: The script MUST run completely unattended with zero interactive prompts.

#### 2. `bin/change_version` Requirements
* Executable file **without `.sh` extension**.
* Implements the unified version manager specification (see [`version-manager` skill](../version-manager/SKILL.md)).

#### 3. `README.md` Requirements
* Clear overview of pre-installed components and SDKs.
* Usage commands: creation (`./create.sh <name>`), access (`./enter.sh <name>`), and provisioning (`setup.sh`).
* Practical code compilation or project run examples.
* Local customization instructions (`.env` overrides).

---

### Phase 5: Global Catalog & Template Registration
* Register the new container in the *Available Environments* table, directory layout, and command sections of the root [`README.md`](../../README.md).
* If new environment variables are introduced, document them in [`.env.example`](../../.env.example).

---

### Phase 6: Static Audits & Live In-Container Smoke Testing (MANDATORY)
Static checks alone are NOT sufficient. The agent MUST verify the sandbox works end-to-end:

#### 1. Static Repository & Script Audit
* Run `./tests/validate-sandboxes.sh` to automatically verify structure, permissions (`100755`), LF line endings, `distrobox.ini` registration, and bash syntax (`bash -n` / `shellcheck`).
* Run `./.githooks/pre-commit` on staged changes and `./.githooks/pre-push` to guarantee zero leaked secrets or personal host paths.

#### 2. Live Container Lifecycle Spin-Up
Create the sandbox on the host:
```bash
./create.sh <name>
```

#### 3. Internal Container Provisioning
Execute the unattended setup script inside the running container:
```bash
distrobox enter <name> -- bash $WORKSPACE_DIR/distrobox-configs/<name>/setup.sh
```

#### 4. Live Runtime Smoke Tests
Execute functional smoke tests inside the container via non-interactive `distrobox enter`:
* Verify primary runtime version (e.g. `python3 --version`, `java -version`, `rustc --version`).
* Verify version manager status (`distrobox enter <name> -- bash -l -c "change_version status"`).
* Test runtime execution with a simple inline script or compilation command.
* Verify version switching functionality (`change_version set <version>`).
* Verify complementary developer CLI tools are accessible and functional.

---

### Phase 7: Integration, Commit & Merge Protocol

#### 1. Feature Branch Commit
Commit staged changes to the feature branch with a semantic commit message:
```bash
git add distrobox.ini .env.example README.md <name>/
./.githooks/pre-commit
git commit -m "feat(<name>): add <name> development sandbox with <toolchain>"
```

#### 2. Integration / Merge Workflow
* **A. Local Pair-Programming (Direct Merge to `main`)**:
  When collaborating directly with the user on the local host without remote pull requests:
  1. Run `./.githooks/pre-push` on the feature branch.
  2. Switch to `main`: `git checkout main`.
  3. Merge feature branch cleanly: `git merge feature/<name>`.
  4. Run final repository audit on `main`: `./.githooks/pre-push`.
  5. Delete the merged local feature branch: `git branch -d feature/<name>`.
  6. Present live test results and clean status to the user.

* **B. Remote Pull Request Protocol**:
  When contributing to a shared repository with PR code review:
  1. Push feature branch: `git push -u origin feature/<name>`.
  2. Complete all sections of [`.github/pull_request_template.md`](../../.github/pull_request_template.md).
  3. Ensure CI workflows are enabled (`gh workflow enable ci.yml`).
