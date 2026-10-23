# AGENTS.md — Instructions for AI Assistants in distrobox-configs

## Repository Overview
`distrobox-configs` contains the centralized declarative manifests, automation scripts, and provisioning logic for developer sandboxes on Fedora Linux using Distrobox and Podman.

## Key Architecture & Sandboxes
- **Manifest:** Declarations in [`distrobox.ini`](./distrobox.ini) defining home isolation, workspace mount, and auto-detected hardware passthrough (`/dev/kvm`, `/dev/dri` are passed through by `create.sh` only when present on the host; overridable via `DISTROBOX_ADDITIONAL_FLAGS`).
- **Sandboxes Managed:**
  - `node-dev`: Node.js 24 LTS, fnm, pnpm, bun, web testing frameworks.
  - `python-dev`: Python 3.13 default (others on-demand via uv), uv, ruff, mypy, pytest.
  - `java-dev`: OpenJDK 21 LTS default, SDKMAN!, Gradle, Maven; GraalVM CE opt-in via `change_version -g`.
  - `android-dev`: Android SDK 35, Command-line Tools, ADB, OpenJDK 21, AVD.

## Key Commands & Workflow
```bash
# Validate sandbox structures, permissions, and manifest synchronization:
./tests/validate-sandboxes.sh

# Run security audit on staged changes or entire repository:
./.githooks/pre-commit --all

# Create or re-create a specific container:
./create.sh node-dev

# Enter a container interactively:
./enter.sh node-dev

# Automated environment verification utility:
bash ./scripts/ensure_distrobox_env.sh -c python-dev -a check
```

## Definition of Done (DoD)
- [ ] `./tests/validate-sandboxes.sh` passes cleanly (100% PASS).
- [ ] `./.githooks/pre-commit --all` reports 0 secrets, 0 private host paths, and 0 personal usernames.
- [ ] All code, documentation, comments, CLI messages, and commit logs are written in clear English.
- [ ] Conventional Commits format is used for all commits (`feat:`, `fix:`, `chore:`, etc.).
- [ ] No duplicate `create.sh` or `enter.sh` exists inside sandbox subdirectories.
