#!/usr/bin/env zsh
# sandbox.sh — macOS sandbox-exec lifecycle and hooks
# Manages sandbox entry, exit, chpwd hooks, and logging

# =============================================================================
# Sandbox configuration (macOS sandbox-exec)
# =============================================================================
typeset -g SANDBOX_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sandbox"
typeset -g SANDBOX_PROFILES_DIR="${SANDBOX_CONFIG_DIR}/profiles"
typeset -g SANDBOX_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sandbox/logs"

# Get the real path to ~/.ssh (resolving symlinks)
function _sandbox_get_ssh_real() {
    python3 -c "import os; print(os.path.realpath(os.path.expanduser('~/.ssh')))"
}

# Return path to sandbox profile template
function _sandbox_get_profile() {
    echo "${SANDBOX_PROFILES_DIR}/default.sb"
}

# Log sandbox events to audit file
function _sandbox_log() {
    local project_name="$1"
    local event_type="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Silently fail if we can't create log dir (e.g., inside sandbox)
    mkdir -p "${SANDBOX_LOG_DIR}" 2>/dev/null || return 0
    local log_file="${SANDBOX_LOG_DIR}/${project_name}.log"

    echo "${timestamp} [${event_type}] ${message}" >> "${log_file}" 2>/dev/null
}

# =============================================================================
# Sandbox entry hook (runs in non-sandbox shells on every cd)
# =============================================================================
# This replaces mise hooks for sandbox entry - zsh chpwd gives us better control
# and avoids race conditions with marker files.
if [[ -z "$IN_SANDBOX" ]]; then
    _sandbox_entry_chpwd() {
        # Skip if currently spawning/exiting a sandbox (prevents re-entry during cd)
        [[ -n "$_SANDBOX_SPAWNING" ]] && return 0

        # Check if current directory is a sandboxed project
        [[ -f ".sandbox" && -f ".mise.toml" ]] || return 0

        # Enter sandbox
        _workon_sandboxed "$(basename "$PWD")" "$PWD"
        local sandbox_exit=$?

        # Explicit exit (not 42) = exit the shell entirely
        if [[ $sandbox_exit -ne 42 ]]; then
            exit $sandbox_exit
        fi
        # Implicit exit (42) - already cd'd to destination by _workon_sandboxed
    }
    chpwd_functions+=(_sandbox_entry_chpwd)
fi

# Legacy function - sandbox entry is now handled by zsh chpwd hook (_sandbox_entry_chpwd)
# Kept for backwards compatibility with workon -s command
function _sandbox_add_hooks() {
    local projdir="$1"
    local mise_file="$projdir/.mise.toml"

    # No mise hooks needed - sandbox detection via .sandbox marker + zsh chpwd
    if grep -q '^\[hooks\]' "$mise_file" 2>/dev/null; then
        echo "Hooks section already exists in $mise_file"
        return 0
    fi

    cat >> "$mise_file" << 'EOF'

[hooks]
# Sandbox entry/exit handled by zsh chpwd hooks, not mise
enter = 'true'
leave = 'true'
EOF

}

# Enter sandboxed environment using macOS sandbox-exec
function _workon_sandboxed() {
    local projname="$1"
    local projdir="$2"

    # Prevent nested sandboxes
    [[ -n "$IN_SANDBOX" ]] && return 0

    # Set spawning guard - prevents _sandbox_entry_chpwd from re-entering during cd
    _SANDBOX_SPAWNING=1

    # Get profile path and resolve SSH real path
    local profile_path
    profile_path=$(_sandbox_get_profile)
    if [[ ! -f "$profile_path" ]]; then
        unset _SANDBOX_SPAWNING
        echo "Error: Sandbox profile not found: $profile_path" >&2
        return 1
    fi
    local ssh_real
    ssh_real=$(_sandbox_get_ssh_real)

    _sandbox_log "$projname" "ENTER" "pid=$$ profile=default dir=$projdir"

    # Pretty sandbox banner
    local cyan='\033[36m'
    local green='\033[1;92m'
    local dim='\033[2m'
    local reset='\033[0m'

    echo -e "${green}▸ sandbox entered${reset}: ${cyan}[$projname]${reset}"
    echo -e "  ${dim}project${reset}  $projdir"
    echo -e "  ${dim}tools${reset}    mise, homebrew, docker"
    echo -e "  ${dim}network${reset}  outbound allowed"

    # cd to project directory (no marker files needed - _SANDBOX_SPAWNING guards us)
    cd "$projdir"

    # Launch sandboxed shell with env vars for starship indicator and chpwd hook
    sandbox-exec -f "$profile_path" \
        -D "HOME=$HOME" \
        -D "PROJECT_DIR=$projdir" \
        -D "SSH_REAL=$ssh_real" \
        env TERM="$TERM" IN_SANDBOX=1 SANDBOX_PROJECT="$projname" SANDBOX_PROJECT_DIR="$projdir" SANDBOX_PARENT_PID=$$ /bin/zsh -i
    local exit_code=$?

    # Handle sandbox exit
    local dest_file="${XDG_CACHE_HOME:-$HOME/.cache}/sandbox/.exit-dest-$$"

    # Show exit message for all exits
    local red='\033[1;91m'
    echo -e "${red}▸ sandbox exited${reset}: ${cyan}[$projname]${reset}"

    if [[ $exit_code -eq 42 && -f "$dest_file" ]]; then
        # Implicit exit - go to intended destination
        local destination=$(<"$dest_file")
        rm -f "$dest_file"
        _sandbox_log "$projname" "EXIT" "pid=$$ implicit dest=$destination"
        cd "$destination"
    elif [[ $exit_code -eq 42 ]]; then
        # Implicit exit but no dest file - stay at project dir
        _sandbox_log "$projname" "EXIT" "pid=$$ implicit (no dest)"
    else
        # Explicit exit - caller handles shell exit
        _sandbox_log "$projname" "EXIT" "pid=$$ explicit"
    fi

    # Clear spawning guard - NOW chpwd hooks can fire again
    unset _SANDBOX_SPAWNING

    # Scenario 5: If we landed in ANOTHER sandboxed project, enter it
    if [[ $exit_code -eq 42 && -f ".sandbox" && -f ".mise.toml" ]]; then
        _workon_sandboxed "$(basename "$PWD")" "$PWD"
        return $?
    fi

    return $exit_code
}

# =============================================================================
# Sandbox auto-exit hook (runs when this file is sourced inside sandbox)
# =============================================================================
if [[ -n "$IN_SANDBOX" && -n "$SANDBOX_PROJECT_DIR" ]]; then
    _sandbox_chpwd() {
        # Exit sandbox if we've left the project directory
        if [[ "$PWD" != "$SANDBOX_PROJECT_DIR"* ]]; then
            # Save destination for parent shell (use parent PID for file), exit with sentinel code 42
            echo "$PWD" > "${XDG_CACHE_HOME:-$HOME/.cache}/sandbox/.exit-dest-$SANDBOX_PARENT_PID"
            exit 42
        fi
    }
    chpwd_functions+=(_sandbox_chpwd)
fi

# =============================================================================
# Auto-enter sandbox on shell startup
# =============================================================================
# Mise hooks only fire on directory change, not shell startup. When a new
# terminal opens directly in a sandboxed project (via Ghostty auto-cd), we
# need to detect the .sandbox marker and enter sandbox mode automatically.
# Skip if _SANDBOX_HOOK is set (we're being sourced by a mise hook, not shell init).

if [[ -z "$_SANDBOX_HOOK" && -z "$IN_SANDBOX" && -f ".sandbox" && -f ".mise.toml" ]]; then
    _workon_sandboxed "$(basename "$PWD")" "$PWD"
    local sandbox_exit=$?
    if [[ $sandbox_exit -ne 42 ]]; then
        exit $sandbox_exit  # Explicit exit - close terminal
    fi
    # Implicit exit (42) - already cd'd to destination by _workon_sandboxed
fi
