---
name: version-manager
description: Unified specification, command contract, and implementation guide for container runtime version managers (change_version). Use when creating or modifying a sandbox's change_version CLI or reviewing its behavior.
compatibility: Applies inside a Distrobox sandbox (bash). The implemented change_version delegates to the sandbox's native tool (fnm, uv, SDKMAN, or sdkmanager); status and local listing must work offline.
license: MIT
---

# 🔄 Skill: Version Manager Contract (`change_version`)

Every sandbox environment that manages multiple runtime or SDK versions (e.g. Java, Python, Node, Android SDKs) MUST provide an executable command at `<name>/bin/change_version`.

This document specifies the user interface contract, argument handling, and behavioral requirements for any `change_version` implementation.

---

## 🎯 Command Interface Contract

All `change_version` scripts must adhere to the following interface:

| Command | Required Behavior |
| :--- | :--- |
| `change_version` *(or `status`)* | Shows current active version, paths, and complementary ecosystem tools. |
| `change_version list` *(or `-l`)* | Lists versions installed locally inside the container. Works offline. |
| `change_version remote` *(or `-r`)* | Lists recommended versions available online from upstream registries. |
| `change_version install <ver>` | Downloads and installs a version without forcing it as default. |
| `change_version set <ver>` | Switches to that version (downloads it first if missing). |
| `change_version <ver>` | Direct shortcut equivalent to `change_version set <ver>`. |
| `change_version help` *(or `-h`)* | Shows help text. **Must work even before the environment is provisioned.** |

---

## ⚙️ Technical Implementation Rules

1. **Naming and Permissions**:
   * File name: strictly `change_version` (NEVER `change_version.sh`).
   * Location: `<name>/bin/change_version` in Git.
   * Target inside container: `$HOME/.local/bin/change_version`.
   * Execution permissions: `chmod +x` (Git mode `100755`).
   * Line endings: Unix `LF` enforced.

2. **Language and Messages**:
   * All outputs, errors, prompts, and help text MUST be strictly in **English**.
   * Use clean formatting with status icons (`✅`, `❌`, `ℹ️`, `⬇️`, `🎯`).

3. **Defensive and Non-Destructive**:
   * Checking status or listing local versions must NEVER require network connectivity.
   * Switching versions must NOT delete or corrupt existing project configurations.
   * If a user requests an invalid version, display an actionable error message and suggest `change_version remote`.

4. **Integration with Project Configs**:
   * If a standard version lockfile is detected in the current working directory (e.g. `.sdkmanrc`, `.python-version`, `build.gradle.kts`), `change_version status` should detect and report it.
