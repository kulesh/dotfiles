#!/usr/bin/env zsh
# git_utils.sh — Git introspection utilities
# Pure functions with no side effects beyond git queries

# Helper function to find the mise project root directory
function find_mise_root() {
    local dir="${PWD:A}"
    while [[ "$dir" != "/" ]]; do
        if [[ -e "$dir/.mise.toml" || -e "$dir/.tool-versions" ]]; then
            echo "$dir"
            return 0
        fi
        dir=${dir:h}
    done
    return 1
}

# Get the mise project root or empty string if not in a mise project
function get_mise_root() {
    find_mise_root
}

# Safe directory change with error handling
function safe_cd() {
    local target_dir="$1"
    if ! cd "$target_dir" 2>/dev/null; then
        echo "❌ Error: Failed to change to directory: $target_dir"
        return 1
    fi
    return 0
}

# Extract git remote information
function get_git_remote_info() {
    local repo_dir="$1"

    if [[ ! -d "$repo_dir/.git" ]]; then
        return 1
    fi

    # Use git -C to avoid cd which triggers mise hooks
    local remote_url=$(git -C "$repo_dir" remote get-url origin 2>/dev/null)

    if [[ -n "$remote_url" ]]; then
        echo "$remote_url"
        return 0
    fi
    return 1
}

# Check if repository has GitHub remote and extract user/repo
function get_github_repo_info() {
    local repo_dir="$1"
    local remote_url=$(get_git_remote_info "$repo_dir")

    if [[ -z "$remote_url" ]]; then
        return 1
    fi

    if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        echo "${match[1]}/${match[2]}"
        return 0
    fi
    return 1
}

# Get last modified time cross-platform
function get_last_modified() {
    local target_path="$1"
    local format="${2:-short}"

    if ! command -v stat >/dev/null; then
        return 1
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if [[ "$format" == "short" ]]; then
            stat -f "%Sm" -t "%b %d" "$target_path" 2>/dev/null
        else
            stat -f "%Sm" -t "%b %d %Y" "$target_path" 2>/dev/null
        fi
    else
        # Linux
        stat -c "%y" "$target_path" 2>/dev/null | cut -d' ' -f1
    fi
}

# Check git status and return structured information
function get_git_status_info() {
    local repo_dir="$1"
    local current_dir="$PWD"

    if [[ ! -d "$repo_dir/.git" ]]; then
        return 1
    fi

    if ! safe_cd "$repo_dir"; then
        return 1
    fi

    local git_status=$(git status --porcelain 2>/dev/null)
    local has_changes=false

    if [[ -n "$git_status" ]]; then
        has_changes=true
    fi

    safe_cd "$current_dir"

    if [[ "$has_changes" == true ]]; then
        return 0  # Has changes
    else
        return 1  # Clean
    fi
}

# Parse GitHub URL and extract repository information
function parse_github_url() {
    local first_arg="$1"
    local second_arg="$2"
    local github_url=""
    local repo_name=""

    if [[ "$first_arg" == "gh" && -n "$second_arg" ]]; then
        # Handle "gh user/repo" format (two arguments)
        if [[ "$second_arg" =~ ^([^/]+)/([^/]+)$ ]]; then
            local user="${match[1]}"
            local repo="${match[2]}"
            github_url="git@github.com:${user}/${repo}.git"
            repo_name="$repo"
        else
            return 1
        fi
    elif [[ "$first_arg" =~ ^https://github\.com/([^/]+)/([^/.]+)(\.git)?/?$ ]]; then
        # Handle full GitHub URL - convert to SSH
        local user="${match[1]}"
        local repo="${match[2]}"
        github_url="git@github.com:${user}/${repo}.git"
        repo_name="$repo"
    elif [[ "$first_arg" =~ ^git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
        # Handle SSH GitHub URL directly
        github_url="$first_arg"
        local repo="${match[2]}"
        # Remove .git suffix if present
        repo_name="${repo%.git}"
    else
        return 1
    fi

    echo "$github_url|$repo_name"
    return 0
}
