# 🟢 Environment: Node.js & Frontend (`node-dev`)

Isolated Distrobox container designed for modern, high-performance **Frontend & Fullstack JavaScript/TypeScript development**: **React**, **Angular**, **Vue**, **Svelte**, **Next.js**, **Nuxt**, **Astro**, powered by **`fnm` (Fast Node Manager)**, **Node.js 24 LTS**, modern package managers (**`pnpm`**, **`npm`**, **`yarn`**, **`bun`**), native compilation tools (`node-gyp`), and headless browser libraries for testing (**Vitest**, **Playwright**, **Cypress**).

---

## 📁 Environment Files

* **[`setup.sh`](./setup.sh)**: Internal sandbox provisioning script (run once inside the container).
* **[`bin/change_version`](./bin/change_version)**: Unified Node.js version manager (automatically installed to `~/.local/bin/change_version`).

---

## 🚀 Getting Started

### 1. Create the container (from the Host at repo root)
```bash
./create.sh node-dev
```
*(Or via the interactive menu: `./create.sh`)*

### 2. Enter the container (from the Host)
```bash
./enter.sh node-dev
```

### 3. Provision tools (ONCE only, INSIDE the container)
```bash
bash $HOME/Workspace/distrobox-configs/node-dev/setup.sh
```

---

## 📦 Installed Components

* **`fnm` (Fast Node Manager)**: High-speed Node.js version manager written in Rust. Automatically switches versions when navigating directories with `.nvmrc` or `.node-version`.
* **Node.js**: Node.js 24 Active LTS configured as default.
* **Modern Package Managers & Runtimes**:
  * **`pnpm`**: High-performance, disk-efficient package manager using hardlinks.
  * **`npm`**: Default package manager bundled with Node.js.
  * **`yarn`**: Enabled via Corepack.
  * **`bun`**: Ultra-fast alternative JavaScript/TypeScript runtime, bundler, and package manager.
* **Native Compilation (`node-gyp`)**:
  * `gcc`, `gcc-c++`, `make`, `python3`, `glibc-devel`, `libstdc++-devel` pre-installed.
  * Guarantees smooth building of native modules (`sharp`, `canvas`, `esbuild`, `node-sass`).
* **Headless Browser Testing Dependencies**:
  * Pre-installs shared system libraries (`nss`, `atk`, `libdrm`, `mesa-libgbm`, `pango`, `alsa-lib`, etc.) required by **Chromium**, **Firefox**, and **WebKit** in headless mode.
  * Ensures **Vitest**, **Playwright**, **Cypress**, and **Puppeteer** run without missing library errors.

---

## 🛠️ Useful Commands

### Unified Version Manager (`change_version`)
The script is copied to `$HOME/.local/bin/change_version` and is directly available in your terminal:

```bash
# 1. View current status (active Node.js, path, fnm, pnpm, npm, bun, package.json detection)
change_version

# 2. List locally installed Node.js versions
change_version list

# 3. List recommended Node.js versions available online
change_version remote

# 4. Install or switch to Node.js 22 Maintenance LTS
change_version 22

# 5. Switch version for current terminal session only (without changing default)
change_version 26 --session
```

### Modern Frontend Workflows

#### 1. React with Vite and Vitest
```bash
# Initialize a new React project with TypeScript
pnpm create vite my-react-app --template react-ts
cd my-react-app

# Install dependencies and testing libraries
pnpm install
pnpm add -D vitest @testing-library/react jsdom

# Run development server and tests
pnpm dev
pnpm vitest run
```

#### 2. Angular CLI
```bash
# Run Angular CLI directly without global pollution
pnpm dlx @angular/cli new my-angular-app
cd my-angular-app
pnpm start
```

#### 3. Ultra-fast Bundling and Scripts with Bun
```bash
# Run TypeScript files directly with zero build step
bun run script.ts

# Install packages with bun
bun install
```

---

## ⚙️ Configuration and Customization

### Local Customization via `.env`
You can configure sandbox defaults before running `setup.sh` via `.env` in the repository root:

```bash
# Default Node.js LTS version (default: 24)
NODE_DEFAULT_VERSION="24"

# Pre-install Bun runtime & package manager (default: true)
INSTALL_BUN=true

# Pre-install headless browser libraries for testing (default: true)
INSTALL_BROWSER_DEPS=true

# Set to true only if you want full desktop windowing packages (X11/Wayland/GTK3)
INSTALL_GUI=false
```
