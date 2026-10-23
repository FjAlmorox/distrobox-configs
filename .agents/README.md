# `.agents/` — AI Agent Knowledge Base

This directory holds portable, task-specific knowledge for AI coding agents
working in this repository. It complements the root [`AGENTS.md`](../AGENTS.md)
(which carries the always-on operating rules) with on-demand **skills**.

## Skills (`.agents/skills/`)

Each subdirectory is a self-contained skill following the open
[Agent Skills specification](https://agentskills.io/specification): a directory
containing a `SKILL.md` file with YAML frontmatter and a Markdown body.

| Skill | Purpose |
| :--- | :--- |
| [`create-sandbox`](./skills/create-sandbox/SKILL.md) | 7-phase protocol to design, build, provision, verify, and integrate a new Distrobox sandbox. |
| [`version-manager`](./skills/version-manager/SKILL.md) | Command contract and implementation rules for each sandbox's `change_version` CLI. |

### Frontmatter conventions

Per the specification, every `SKILL.md` includes at least:

* **`name`** — lowercase letters, numbers, and hyphens only; must match the
  parent directory name (e.g. `create-sandbox`).
* **`description`** — what the skill does **and when to use it**, so agents can
  decide whether to activate it.

Optional fields used here:

* **`compatibility`** — environment requirements (Fedora host, Distrobox, bash,
  network access).
* **`license`** — the skill license (MIT, matching the repository).

### How agents use these skills

Agents load skill metadata (name + description) at startup and pull in the full
`SKILL.md` body only when a task matches. Keep each `SKILL.md` focused and move
long reference material into separate files when it grows, following the
specification's progressive-disclosure guidance.
