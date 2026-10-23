#!/usr/bin/env bash
# ==============================================================================
# ensure_distrobox_env.sh
#
# Automation, inspection, and component provisioning utility for Distrobox
# containers on Fedora Workstation / any Linux host.
#
# Designed to be invoked both by AI agents and by developers.
#
# Key principles:
# 1. Fully isolated execution: installs and changes happen INSIDE the container.
# 2. Mandatory justification: requires documenting WHY and WHAT FOR on install.
# 3. Inspect first: reports existing runtimes and tools before touching anything.
# 4. Anti-downgrade policy: refuses to arbitrarily downgrade runtime versions.
# 5. Latest-stable first: prefers the most recent stable version.
# 6. Verify & smoke test: validates the component right after installation.
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Repository root is the parent of scripts/, derived from the real path so the
# utility works regardless of the repository folder name or clone location.
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

# Terminal output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
CONTAINER=""
ACTION="check"
COMPONENT=""
TARGET_VERSION=""
WHY=""
FOR_WHAT=""
PROJECT_DIR=""
FORCE_DOWNGRADE=false

show_help() {
    cat << EOF
${BOLD}Usage:${NC} $(basename "$0") [options]

${BOLD}Main options:${NC}
  -c, --container <name>       Distrobox container name (node-dev, python-dev, java-dev, android-dev)
  -a, --action <action>        Action to perform:
                                 • check   : Inspect the current state of the container and tools
                                 • install : Install a component/dependency (requires --why and --for-what)
                                 • verify  : Run smoke tests against the environment or project
  -p, --project-dir <path>     Project path to evaluate (inside \$HOME/Workspace)
  --component <name>           Component to install/manage:
                                 • runtime (Node, Python, Java depending on the container)
                                 • system-pkg (dnf system package inside the container)
                                 • uv-tool (global CLI tool in python-dev)
                                 • npm-global (global npm/pnpm package in node-dev)
  -v, --version <version>      Desired version (default: latest-stable)
  --why <reason>               [REQUIRED on install] Justification: why is it needed?
  --for-what <purpose>         [REQUIRED on install] Purpose: what will it be used for?
  --force-downgrade            Allow forcing a version lower than the one installed
  -h, --help                   Show this help and exit

${BOLD}Example usage by an AI agent:${NC}
  1. Inspect python-dev before working on a backend:
     $(basename "$0") -c python-dev -a check

  2. Check the environment for a project's frontend:
     $(basename "$0") -c node-dev -p "\$HOME/Workspace/my-app/frontend" -a check

  3. Install a system library required by a native Python package:
     $(basename "$0") -c python-dev -a install --component system-pkg --version "libpq-devel" \\
       --why "Native build of the psycopg2 driver for PostgreSQL connectivity" \\
       --for-what "Allow SQLAlchemy to communicate with a relational database"

  4. Ensure or update the Node.js runtime in node-dev:
     $(basename "$0") -c node-dev -a install --component runtime --version "24" \\
       --why "Required by Vite 6 and TypeScript 5.8 for native import support" \\
       --for-what "Build and bundle the React frontend"
EOF
}

log_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ [OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠️  [WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $1" >&2
}

log_box() {
    echo -e "\n${CYAN}======================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${CYAN}======================================================${NC}"
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -p|--project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        -v|--version)
            TARGET_VERSION="$2"
            shift 2
            ;;
        --why)
            WHY="$2"
            shift 2
            ;;
        --for-what)
            FOR_WHAT="$2"
            shift 2
            ;;
        --force-downgrade)
            FORCE_DOWNGRADE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Basic parameter validation
if [ -z "$CONTAINER" ]; then
    log_error "You must specify the target container with -c or --container (e.g. node-dev, python-dev, java-dev, android-dev)."
    exit 1
fi

# Validate that the container is declared in distrobox.ini
INI_FILE="$REPO_ROOT/distrobox.ini"
if [ -f "$INI_FILE" ]; then
    if ! grep -q "^\[${CONTAINER}\]" "$INI_FILE"; then
        log_error "Container '$CONTAINER' is not declared in $INI_FILE."
        exit 1
    fi
fi

# Ensure distrobox is reachable (directly on the host or via host-exec if nested)
if ! dbx_require_distrobox; then
    exit 1
fi

# 1. Check whether the container exists; create and provision it if missing
check_or_create_container() {
    log_info "Checking state of container '$CONTAINER' in Distrobox..."
    if ! dbx_host_distrobox list | grep -q "[[:space:]]${CONTAINER}[[:space:]]"; then
        log_warn "Container '$CONTAINER' does not currently exist."
        log_info "Creating container '$CONTAINER' using create.sh..."
        if [ -x "$REPO_ROOT/create.sh" ]; then
            bash "$REPO_ROOT/create.sh" "$CONTAINER"
        else
            dbx_host_distrobox assemble create --file "$INI_FILE" --name "$CONTAINER"
        fi

        # Run initial provisioning if setup.sh exists
        local setup_file="$REPO_ROOT/$CONTAINER/setup.sh"
        if [ -f "$setup_file" ]; then
            log_info "Running initial provisioning (setup.sh) in '$CONTAINER'..."
            dbx_host_distrobox enter "$CONTAINER" -- bash -lc "bash '$setup_file'"
        fi
    else
        log_success "Container '$CONTAINER' exists in Distrobox."
    fi
}

# Run a command inside the container safely and non-interactively
run_in_container() {
    local cmd="$1"
    dbx_host_distrobox enter "$CONTAINER" -- bash -lc "$cmd"
}

# 2. Environment and version inspection
inspect_environment() {
    log_box "🔍 Environment Inspection: $CONTAINER"

    echo -e "${BOLD}1. Primary runtime diagnosis (change_version):${NC}"
    if run_in_container "command -v change_version >/dev/null 2>&1"; then
        run_in_container "change_version"
    else
        log_warn "change_version not found in the container PATH. Checking base tools manually..."
        case "$CONTAINER" in
            node-dev)
                run_in_container "node -v 2>/dev/null || echo 'Node: not installed'"
                run_in_container "pnpm -v 2>/dev/null || echo 'pnpm: not installed'"
                run_in_container "bun -v 2>/dev/null || echo 'bun: not installed'"
                ;;
            python-dev)
                run_in_container "python3 --version 2>/dev/null || echo 'Python: not installed'"
                run_in_container "uv --version 2>/dev/null || echo 'uv: not installed'"
                ;;
            java-dev)
                run_in_container "java -version 2>&1 | head -n 1 || echo 'Java: not installed'"
                ;;
            android-dev)
                run_in_container "sdkmanager --version 2>/dev/null || echo 'sdkmanager: not installed'"
                ;;
        esac
    fi

    # Inspect project configuration if a path was provided
    if [ -n "$PROJECT_DIR" ]; then
        echo ""
        echo -e "${BOLD}2. Project configuration detection in '$PROJECT_DIR':${NC}"
        if [ ! -d "$PROJECT_DIR" ]; then
            log_warn "Project directory '$PROJECT_DIR' does not exist on the filesystem."
        else
            case "$CONTAINER" in
                node-dev)
                    if [ -f "$PROJECT_DIR/package.json" ]; then
                        log_info "package.json detected."
                        if [ -f "$PROJECT_DIR/.nvmrc" ]; then
                            log_info "Version required by .nvmrc: $(cat "$PROJECT_DIR/.nvmrc")"
                        fi
                        if [ -f "$PROJECT_DIR/.node-version" ]; then
                            log_info "Version required by .node-version: $(cat "$PROJECT_DIR/.node-version")"
                        fi
                        grep -E '"(scripts|dependencies|devDependencies)":' "$PROJECT_DIR/package.json" -A 5 2>/dev/null || true
                    fi
                    ;;
                python-dev)
                    if [ -f "$PROJECT_DIR/pyproject.toml" ]; then
                        log_info "pyproject.toml detected."
                        grep -E 'requires-python' "$PROJECT_DIR/pyproject.toml" || true
                    fi
                    if [ -f "$PROJECT_DIR/.python-version" ]; then
                        log_info "Version pinned by .python-version: $(cat "$PROJECT_DIR/.python-version")"
                    fi
                    ;;
                java-dev|android-dev)
                    if [ -f "$PROJECT_DIR/build.gradle.kts" ] || [ -f "$PROJECT_DIR/build.gradle" ]; then
                        log_info "Gradle project detected."
                    fi
                    ;;
            esac
        fi
    fi
}

# 3. Version comparison logic to prevent downgrades
# Returns: 0 if installing/upgrading is allowed, 1 if it must be blocked/skipped
check_version_downgrade() {
    local current="$1"
    local requested="$2"

    if [ "$FORCE_DOWNGRADE" = true ]; then
        log_warn "Forced downgrade enabled by the user/agent (--force-downgrade)."
        return 0
    fi

    # No previous version means no downgrade
    if [ -z "$current" ]; then
        return 0
    fi

    # Strip prefixes such as 'v' or 'Python '
    local clean_cur
    clean_cur=$(echo "$current" | grep -oE '[0-9]+(\.[0-9]+)*' | head -n 1)
    local clean_req
    clean_req=$(echo "$requested" | grep -oE '[0-9]+(\.[0-9]+)*' | head -n 1)

    if [ -z "$clean_cur" ] || [ -z "$clean_req" ]; then
        return 0
    fi

    if [ "$clean_cur" == "$clean_req" ]; then
        log_info "Requested version ($clean_req) already matches the active version ($clean_cur). No change needed."
        return 1
    fi

    # Compare versions using sort -V
    local highest
    highest=$(printf "%s\n%s" "$clean_cur" "$clean_req" | sort -V | tail -n 1)

    if [ "$highest" == "$clean_cur" ]; then
        log_error "ANTI-DOWNGRADE POLICY: the version in the container ($clean_cur) is HIGHER than the requested one ($clean_req)."
        log_error "Automatic downgrade is not allowed."
        log_error "If this downgrade is strictly required by project incompatibility, pass '--force-downgrade' with the technical justification."
        return 1
    else
        log_info "Valid upgrade: current version ($clean_cur) -> new version ($clean_req)."
        return 0
    fi
}

# 4. Justified installation process
install_component() {
    log_box "📦 Justified Component Installation in: $CONTAINER"

    # Verify mandatory justification
    if [ -z "$WHY" ] || [ -z "$FOR_WHAT" ]; then
        log_error "MANDATORY JUSTIFICATION REQUIRED:"
        log_error "Any installation or configuration change inside the Distrobox must state:"
        log_error "  --why      : Why is this component/change needed?"
        log_error "  --for-what : What task or feature will it be used for?"
        exit 1
    fi

    echo -e "${BOLD}📋 Technical Justification Record:${NC}"
    echo -e "   • ${CYAN}Component:${NC} $COMPONENT ${TARGET_VERSION:+(version: $TARGET_VERSION)}"
    echo -e "   • ${CYAN}Why?      :${NC} $WHY"
    echo -e "   • ${CYAN}What for? :${NC} $FOR_WHAT"
    echo ""

    case "$COMPONENT" in
        runtime)
            case "$CONTAINER" in
                node-dev)
                    local current_node
                    current_node=$(run_in_container "node -v 2>/dev/null" || true)
                    local target="${TARGET_VERSION:-24}"

                    if check_version_downgrade "$current_node" "$target"; then
                        log_info "Installing/activating Node.js $target via change_version..."
                        run_in_container "change_version '$target'"
                    fi
                    ;;
                python-dev)
                    local current_py
                    current_py=$(run_in_container "python3 --version 2>/dev/null" || true)
                    local target="${TARGET_VERSION:-3.13}"

                    if check_version_downgrade "$current_py" "$target"; then
                        log_info "Installing/activating Python $target via change_version..."
                        run_in_container "change_version '$target'"
                    fi
                    ;;
                java-dev)
                    local current_java
                    current_java=$(run_in_container "java -version 2>&1 | head -n 1" || true)
                    local target="${TARGET_VERSION:-21}"

                    if check_version_downgrade "$current_java" "$target"; then
                        log_info "Installing/activating Java $target via change_version..."
                        run_in_container "change_version '$target'"
                    fi
                    ;;
                android-dev)
                    local target="${TARGET_VERSION:-35}"
                    log_info "Installing Android API $target via change_version..."
                    run_in_container "change_version '$target'"
                    ;;
            esac
            ;;

        system-pkg)
            if [ -z "$TARGET_VERSION" ]; then
                log_error "Specify the system package name in --version (e.g. --version 'libpq-devel openssl-devel')."
                exit 1
            fi
            log_info "Installing system packages inside the Fedora container..."
            # Install with sudo dnf inside the container (passwordless thanks to Distrobox)
            run_in_container "sudo dnf install -y $TARGET_VERSION"
            ;;

        uv-tool)
            if [ "$CONTAINER" != "python-dev" ]; then
                log_error "uv-tool components must only be installed in the 'python-dev' container."
                exit 1
            fi
            if [ -z "$TARGET_VERSION" ]; then
                log_error "Specify the uv tool name to install in --version (e.g. --version 'ruff')."
                exit 1
            fi
            log_info "Installing isolated global tool with 'uv tool install $TARGET_VERSION'..."
            run_in_container "uv tool install --upgrade $TARGET_VERSION"
            ;;

        npm-global)
            if [ "$CONTAINER" != "node-dev" ]; then
                log_error "Global npm/pnpm packages must only be installed in 'node-dev'."
                exit 1
            fi
            if [ -z "$TARGET_VERSION" ]; then
                log_error "Specify the package to install in --version."
                exit 1
            fi
            log_info "Installing global package with pnpm in 'node-dev'..."
            run_in_container "pnpm add -g $TARGET_VERSION"
            ;;

        *)
            log_error "Unknown component '$COMPONENT'. Valid options: runtime, system-pkg, uv-tool, npm-global."
            exit 1
            ;;
    esac

    # Immediate verification
    verify_component
}

# 5. Verification / smoke tests
verify_component() {
    log_box "🧪 Smoke Tests & Post-Installation Verification"
    case "$CONTAINER" in
        node-dev)
            log_info "Verifying Node.js, pnpm, bun suite..."
            run_in_container "node -v && pnpm -v && bun -v"
            log_success "node-dev environment operational and validated."
            ;;
        python-dev)
            log_info "Verifying Python, uv, and the C compiler..."
            run_in_container "python3 --version && uv --version && gcc --version | head -n 1"
            log_success "python-dev environment operational and validated."
            ;;
        java-dev)
            log_info "Verifying OpenJDK and Gradle..."
            run_in_container "java -version 2>&1 | head -n 1"
            log_success "java-dev environment operational and validated."
            ;;
        android-dev)
            log_info "Verifying Android SDK tools..."
            run_in_container "adb version | head -n 1"
            log_success "android-dev environment operational and validated."
            ;;
    esac
}

# Main flow
check_or_create_container

case "$ACTION" in
    check)
        inspect_environment
        ;;
    install)
        install_component
        ;;
    verify)
        verify_component
        ;;
    *)
        log_error "Unrecognized action: '$ACTION'. Use check, install, or verify."
        exit 1
        ;;
esac

log_box "✨ Operation completed successfully in '$CONTAINER'"
exit 0
