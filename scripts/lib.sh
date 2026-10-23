#!/usr/bin/env bash
# ==============================================================================
# scripts/lib.sh - Shared helper library for distrobox-configs
#
# Sourced by host orchestration scripts (create.sh, enter.sh) and automation
# utilities. Centralizes environment detection, repository path resolution, and
# nested-container host delegation so the logic lives in a single place (DRY).
#
# This library makes NO assumptions about the repository's directory name or
# its location on disk: everything is derived from the caller's real path.
# ==============================================================================

# ------------------------------------------------------------------------------
# dbx_repo_root <caller_script_path>
#
# Resolve the absolute path to the repository root given the path of the script
# that sourced this library. Works regardless of the repo folder name or where
# it was cloned. Scripts living at the repo root pass "${BASH_SOURCE[0]}" of
# themselves; scripts under scripts/ get the parent directory resolved for them.
# ------------------------------------------------------------------------------
dbx_script_dir() {
    local src="$1"
    cd "$(dirname "$src")" && pwd
}

# ------------------------------------------------------------------------------
# dbx_in_container
#
# Return 0 (true) if the current shell is running inside a Distrobox/OCI
# container, 1 (false) otherwise.
#
# Detection order (per upstream Distrobox guidance and common container markers):
#   1. $CONTAINER_ID        -> canonical Distrobox marker (set inside a distrobox)
#   2. /run/.containerenv    -> Podman marker
#   3. /run/host/container-manager -> Distrobox/Toolbx host-integration marker
#   4. /.dockerenv           -> Docker marker
# ------------------------------------------------------------------------------
dbx_in_container() {
    if [ -n "${CONTAINER_ID:-}" ] \
        || [ -e /run/.containerenv ] \
        || [ -f /run/host/container-manager ] \
        || [ -f /.dockerenv ]; then
        return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# dbx_load_env <repo_root>
#
# Source an optional local .env override file from the repository root, if it
# exists. Kept in one place so every entry point loads overrides consistently.
# ------------------------------------------------------------------------------
dbx_load_env() {
    local repo_root="$1"
    if [ -f "$repo_root/.env" ]; then
        # shellcheck source=/dev/null
        source "$repo_root/.env"
    fi
}

# ------------------------------------------------------------------------------
# dbx_detect_hardware_flags
#
# Echo the Distrobox additional_flags appropriate for the current host,
# auto-detecting hardware passthrough devices so the repository works on
# desktops, headless servers, cloud VMs, and CI without manual configuration.
#
# Precedence:
#   1. If DISTROBOX_ADDITIONAL_FLAGS is already set (even to ""), respect it
#      verbatim. This lets users force a specific value via .env.
#   2. Otherwise, include "--device /dev/kvm" and/or "--device /dev/dri" only
#      when those device nodes actually exist on the host.
# ------------------------------------------------------------------------------
dbx_detect_hardware_flags() {
    if [ -n "${DISTROBOX_ADDITIONAL_FLAGS+set}" ]; then
        printf '%s' "$DISTROBOX_ADDITIONAL_FLAGS"
        return 0
    fi

    local flags=""
    if [ -e /dev/kvm ]; then
        flags="$flags --device /dev/kvm"
    fi
    if [ -d /dev/dri ]; then
        flags="$flags --device /dev/dri"
    fi

    # Trim leading space
    printf '%s' "${flags# }"
}

# ------------------------------------------------------------------------------
# dbx_host_distrobox <args...>
#
# Run the "distrobox" command on the host. When called from inside a nested
# Distrobox container, delegate to the host via distrobox-host-exec (host-spawn)
# so that create/enter operations target the host's container manager rather
# than failing inside the guest. When called on the host, run distrobox directly.
#
# Set DBX_AUTO_INSTALL_HOST_SPAWN=1 to auto-approve host-spawn installation in
# the guest; otherwise the user is prompted by distrobox-host-exec as usual.
# ------------------------------------------------------------------------------
dbx_host_distrobox() {
    if dbx_in_container; then
        if ! command -v distrobox-host-exec >/dev/null 2>&1; then
            echo "❌ Error: running inside a container but 'distrobox-host-exec' is not available." >&2
            echo "   It is required to invoke the host's Distrobox from within a nested container." >&2
            echo "   Install the Distrobox integration tools in this container, or run from the host." >&2
            return 1
        fi
        if [ "${DBX_AUTO_INSTALL_HOST_SPAWN:-0}" = "1" ]; then
            distrobox-host-exec --yes distrobox "$@"
        else
            distrobox-host-exec distrobox "$@"
        fi
    else
        distrobox "$@"
    fi
}

# ------------------------------------------------------------------------------
# dbx_exec_host_distrobox <args...>
#
# Same as dbx_host_distrobox but replaces the current process (exec) on the host
# path, preserving the original "exec distrobox enter ..." semantics for the
# interactive enter flow. Falls back to a normal call when nested so the guest
# error handling in dbx_host_distrobox still applies.
# ------------------------------------------------------------------------------
dbx_exec_host_distrobox() {
    if dbx_in_container; then
        dbx_host_distrobox "$@"
    else
        exec distrobox "$@"
    fi
}

# ------------------------------------------------------------------------------
# dbx_require_distrobox
#
# Ensure the "distrobox" command is reachable from the current context (either
# directly on the host, or on the host via distrobox-host-exec when nested).
# Prints an actionable error and returns 1 if not.
# ------------------------------------------------------------------------------
dbx_require_distrobox() {
    if dbx_in_container; then
        if command -v distrobox-host-exec >/dev/null 2>&1; then
            return 0
        fi
        echo "❌ Error: 'distrobox' is not reachable from inside this container." >&2
        echo "   Install 'distrobox-host-exec' here, or run this script directly on the host." >&2
        return 1
    fi

    if command -v distrobox >/dev/null 2>&1; then
        return 0
    fi
    echo "❌ Error: 'distrobox' is not installed or not available on host." >&2
    echo "   Install it with: sudo dnf install distrobox" >&2
    return 1
}
