## 📋 Description of Changes

<!-- Provide a brief description of what this PR introduces, fixes, or refactors. -->

## 📦 Environment / Scope Details

<!-- If introducing or modifying a sandbox environment, complete this section: -->
- **Container Name**: `<!-- e.g. python-dev, kubernetes, ubuntu-test -->`
- **Base Image**: `<!-- e.g. registry.fedoraproject.org/fedora-toolbox:44 -->`
- **Isolated `$HOME`**: `~/.local/share/distrobox-homes/<name>`
- **Pre-installed SDKs / Toolchains**: `<!-- e.g. Python 3.12, pyenv, poetry -->`
- **CLI Commands in `bin/`**: `<!-- e.g. change_version -->`

## 🧪 Testing Performed

<!-- Describe the manual or automated tests conducted to verify these changes. -->
- [ ] Container created successfully via `./create.sh <name>`
- [ ] Container entered cleanly via `./enter.sh <name>`
- [ ] `setup.sh` executed idempotently without interactive prompts
- [ ] `change_version` tested for `status`, `list`, `remote`, `set` (if applicable)

## ✅ Definition of Done (DoD) Checklist

- [ ] **Distrobox Declaration**: Declared in [`distrobox.ini`](./distrobox.ini) with isolated home, workspace mount, and auto-detected hardware passthrough (`/dev/kvm`, `/dev/dri` passed through only when present; overridable via `DISTROBOX_ADDITIONAL_FLAGS`).
- [ ] **No Root Script Duplication**: No duplicate `create.sh` or `enter.sh` exists inside the subfolder.
- [ ] **CLI Commands**: All user CLI commands reside in `<name>/bin/` without `.sh` extension and have `chmod +x` permissions (`mode 100755`).
- [ ] **Idempotent Provisioning**: `setup.sh` is 100% unattended and copies `bin/*` into `$HOME/.local/bin/`.
- [ ] **Documentation Updated**: Dedicated [`<name>/README.md`](./README.md) added and environment registered in main [`README.md`](./README.md).
- [ ] **Structural Validation**: Repository cleanly passes `./tests/validate-sandboxes.sh` (manifest, structure, permissions `100755`, line endings, `bash -n`).
- [ ] **Security & Privacy Audit**: `./.githooks/pre-commit --all` and `./.githooks/pre-push` pass cleanly (zero private paths `/home/...`, usernames, or secrets).
- [ ] **English Language Standard**: All code, documentation, comments, CLI messages, and commit logs are strictly written in English.
