# 🐍 Environment: Python (`python-dev`)

Isolated Distrobox container for modern, high-performance Python development powered by **Astral `uv`**, modern Python runtimes (**CPython 3.13** default, **3.14**, and free-threaded builds), native C compilation headers, and essential developer quality tools (**Ruff**, **Mypy**, **Pytest**, **IPython**, **Pre-commit**).

---

## 📁 Environment Files

* **[`setup.sh`](./setup.sh)**: Internal sandbox provisioning script (run once inside the container).
* **[`bin/change_version`](./bin/change_version)**: Unified Python version manager (automatically installed to `~/.local/bin/change_version`).

---

## 🚀 Getting Started

### 1. Create the container (from the Host at repo root)
```bash
./create.sh python-dev
```
*(Or via the interactive menu: `./create.sh`)*

### 2. Enter the container (from the Host)
```bash
./enter.sh python-dev
```

### 3. Provision tools (ONCE only, INSIDE the container)
```bash
bash $HOME/Workspace/distrobox-configs/python-dev/setup.sh
```

---

## 📦 Installed Components

* **Astral `uv`**: Ultra-fast Python package installer, dependency resolver, virtual environment manager, and tool runner written in Rust.
* **Python**: CPython 3.13 configured as the default runtime.
* **Native Compilation Toolchain & C Headers**:
  * Compilers: `gcc`, `gcc-c++`, `make`, `glibc-devel`.
  * Development headers: `libffi-devel`, `openssl-devel`, `sqlite-devel`, `zlib-devel`, `bzip2-devel`, `readline-devel`, `xz-devel`.
  * Guarantees seamless compilation of packages containing native C/C++ extensions (`psycopg2`, `cryptography`, `pillow`, `uvloop`, `cffi`, etc.).
* **Pre-installed Developer CLI Tools** (installed in isolated environments via `uv tool`):
  * **`ruff`**: Extremely fast Python linter and code formatter (replaces Black, Flake8, and isort).
  * **`mypy`**: Static type checker for Python.
  * **`pytest`**: Industry standard test framework.
  * **`ipython`**: Powerful interactive terminal REPL with syntax highlighting and auto-completion.
  * **`pre-commit`**: Git hook manager for code quality enforcement.
* **Headless Architecture by Default**:
  * Designed for rapid provisioning (< 30s) and zero bloat.
  * Omits desktop GUI libraries by default (`INSTALL_GUI=false`).

---

## 🛠️ Useful Commands

### Unified Version Manager (`change_version`)
The script is installed to `$HOME/.local/bin/change_version` and is directly available in your terminal:

```bash
# 1. View current status (active Python runtime, path, uv version, active virtualenv)
change_version

# 2. List locally installed Python runtimes
change_version list

# 3. List recommended Python releases available online
change_version remote

# 4. Install or switch to Python 3.14
change_version 3.14

# 5. Switch to experimental free-threaded (no-GIL) Python 3.13
change_version 3.13t

# 6. Pin Python version for current project (.python-version)
change_version set 3.13 --project
```

### Modern Python Workflows with `uv`

```bash
# 1. Initialize a new Python project
uv init my-project
cd my-project

# 2. Add dependencies (automatically manages pyproject.toml & lockfile)
uv add fastapi uvicorn

# 3. Add development-only dependencies
uv add --dev pytest ruff

# 4. Run commands or scripts inside the project environment
uv run python main.py
uv run pytest

# 5. Run single-file scripts with ephemeral dependencies (no virtualenv needed)
uv run --with requests --with rich script.py

# 6. Run standalone tools on the fly without installing
uvx ruff check .
```

---

## ⚙️ Configuration and Customization

### Local Customization via `.env`
You can configure sandbox defaults before running `setup.sh` via `.env` in the repository root:

```bash
# Set default Python version (default: 3.13)
PYTHON_DEFAULT_VERSION="3.13"

# Toggle pre-installation of CLI developer tools (ruff, mypy, pytest, ipython, pre-commit)
INSTALL_PYTHON_DEV_TOOLS=true

# Optional: Enable GUI & desktop display support if you need Tkinter or graphical windows
INSTALL_GUI=false
```
