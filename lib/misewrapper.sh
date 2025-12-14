#!/usr/bin/env zsh
# misewrapper.zsh
# A wrapper script for mise-en-place (https://mise.jdx.dev)
# Providing convenient project management functions

SCRIPT_DIR="${0:a:h:h}"
source "$SCRIPT_DIR/include/shared_vars.sh"

# Configuration
typeset -g MISE_PROJECTS_DIR=$PROJECT_DIR

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
    }
    chpwd_functions+=(_sandbox_entry_chpwd)
fi

# Legacy function - sandbox entry is now handled by zsh chpwd hook (_sandbox_entry_chpwd)
# Kept for backwards compatibility with workon -s command
function _sandbox_add_hooks() {
    local projdir="$1"
    local mise_file="$projdir/.mise.toml"

    # No mise hooks needed - sandbox detection via .sandbox marker + zsh chpwd
    # Just add no-op hooks to prevent mise from complaining about missing hooks
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

    # Save original directory to restore after sandbox exits
    local original_dir="$PWD"

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
        # Explicit exit - restore original dir
        _sandbox_log "$projname" "EXIT" "pid=$$ code=$exit_code"
        cd "$original_dir"
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

# Change to the mise project directory
function cdproject() {
  local mise_dir=$(get_mise_root)
  
  if [[ -z "$mise_dir" ]]; then
    echo "Not in a mise project"
    safe_cd "$HOME_DIR"
    return 1
  fi

  safe_cd "$mise_dir"
}

# Enhanced function to list available project types using mise's native descriptions
list_project_types() {
    echo "Available project types:"
    echo ""
    
    # Use mise tasks to get tasks with descriptions
    local tasks_output=$(mise tasks ls 2>/dev/null)
    
    if [[ -z "$tasks_output" ]]; then
        echo "  (none found)"
        return 1
    fi
    
    # Filter for mkproject tasks and format them
    local mkproject_tasks=$(echo "$tasks_output" | grep "^mkproject:")
    
    if [[ -z "$mkproject_tasks" ]]; then
        echo "  (none found)"
        return 1
    fi
    
    # Find maximum template name length for alignment
    local max_name_length=0
    echo "$mkproject_tasks" | while IFS= read -r line; do
        local task_name=$(echo "$line" | awk '{print $1}' | sed 's/mkproject://')
        if [[ ${#task_name} -gt $max_name_length ]]; then
            max_name_length=${#task_name}
        fi
    done
    
    # Use a minimum width of 12 characters
    if [[ $max_name_length -lt 12 ]]; then
        max_name_length=12
    fi
    
    # Parse and display tasks with better parsing
    echo "$mkproject_tasks" | while IFS= read -r line; do
        # More robust parsing: get first column, last column, everything in between
        local task_name=$(echo "$line" | awk '{print $1}' | sed 's/mkproject://')
        local source=$(echo "$line" | awk '{print $NF}')
        local description=""
        
        # Extract description as everything between task name and source
        local temp_line="$line"
        temp_line="${temp_line#*[[:space:]]}"  # Remove first column
        temp_line="${temp_line%[[:space:]]*$source}"  # Remove source from end
        description=$(echo "$temp_line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        
        # If no description or description looks like the full line, show generic text
        if [[ -z "$description" || "$description" == "$task_name" ]]; then
            description="Project template"
        fi
        
        # Format with dynamic alignment
        printf "  %-${max_name_length}s  %s\n" "$task_name" "$description"
    done
    
    echo ""
    echo "Usage: mkproject <project_name> [template_type]"
    echo "       Default template: base"
    echo ""
    echo "To add descriptions to your templates, add this line to your task files:"
    echo "  #MISE description=\"Your description here\""
}

# Create a new project
mkproject() {
    local project_name="$1"
    local project_type="${2:-base}"
    
    if [[ -z "$project_name" ]]; then
        echo "Usage: mkproject <project_name> [project_type]"
        list_project_types
        return 1
    fi
    
    local project_path="${MISE_PROJECTS_DIR}/${project_name}"
    
    # Check if project already exists
    if [[ -d "$project_path" ]]; then
        echo "❌ Error: Project '$project_name' already exists at $project_path"
        echo "   Use 'workon $project_name' to switch to existing project"
        echo "   Or choose a different project name"
        return 1
    fi
    
    # Check if the project type exists
    if ! mise tasks ls 2>/dev/null | grep -q "^mkproject:$project_type"; then
        echo "❌ Error: Project type '$project_type' not found"
        list_project_types
        return 1
    fi
    
    echo "Creating $project_type project: $project_name"
    mkdir -p "$project_path"
    
    # Create basic .mise.toml in the project directory
    echo "" > "$project_path/.mise.toml"
    mise trust "$project_path/.mise.toml"
    
    # Run the project setup task in the project directory
    if mise run --cd "$project_path" "mkproject:$project_type"; then
        echo "✅ Project '$project_name' created successfully"
        echo "📁 Location: $project_path"
        safe_cd "$project_path"
    else
        echo "❌ Error: Failed to create $project_type project"
        echo "   ⚠️  Incomplete project left at: $project_path"
        echo "   You may want to manually remove it or investigate the issue"
        return 1
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
    elif [[ "$first_arg" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)?/?$ ]]; then
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

# Clone repository content with conflict resolution
function clone_repository_content() {
    local github_url="$1"
    local repo_name="$2"
    
    # Set up git remote
    echo "🔗 Setting up GitHub remote..."
    if ! git remote add origin "$github_url"; then
        echo "❌ Error: Failed to add GitHub remote"
        echo "   ⚠️  Project created but not linked to GitHub"
        return 1
    fi
    
    # Try to pull from main branch first, then master
    echo "⬇️  Pulling repository content..."
    local pulled=false
    
    # Try main branch with unrelated histories merge
    if git pull origin main --allow-unrelated-histories --no-edit 2>/dev/null; then
        pulled=true
        echo "✅ Successfully pulled from 'main' branch"
    # If that fails due to conflicts, force reset to remote
    elif git fetch origin main 2>/dev/null && git reset --hard origin/main 2>/dev/null; then
        pulled=true
        echo "✅ Successfully pulled from 'main' branch (with reset)"
    # Try master branch with unrelated histories merge
    elif git pull origin master --allow-unrelated-histories --no-edit 2>/dev/null; then
        pulled=true
        echo "✅ Successfully pulled from 'master' branch"
    # If that fails due to conflicts, force reset to remote
    elif git fetch origin master 2>/dev/null && git reset --hard origin/master 2>/dev/null; then
        pulled=true
        echo "✅ Successfully pulled from 'master' branch (with reset)"
    else
        echo "❌ Error: Failed to pull from repository"
        echo "   Possible causes:"
        echo "   - Repository doesn't exist or is private"
        echo "   - Network connection issues"
        echo "   - Repository is empty"
        echo "   - Authentication required"
        echo ""
        echo "   ⚠️  Base project created with GitHub remote configured"
        echo "   You can manually pull with: git pull origin <branch_name>"
        return 1
    fi
    
    # Trust mise config if it was pulled from the repo
    if [[ -e ".mise.toml" ]]; then
        echo "🔧 Trusting mise configuration from repository..."
        mise trust .mise.toml
    fi
    
    return 0
}

# Clone a GitHub project using mkproject base template
cloneproject() {
    local first_arg="$1"
    local second_arg="$2"
    
    if [[ -z "$first_arg" ]]; then
        echo "Usage: cloneproject <github_url_or_gh_user/repo>"
        echo "Examples:"
        echo "  cloneproject gh kulesh/example"
        echo "  cloneproject https://github.com/kulesh/example.git"
        echo "  cloneproject git@github.com:kulesh/example.git"
        return 1
    fi
    
    # Parse GitHub URL
    local url_info=$(parse_github_url "$first_arg" "$second_arg")
    if [[ $? -ne 0 ]]; then
        echo "❌ Error: Invalid format. Use 'gh user/repo' or full GitHub URL"
        echo "Examples:"
        echo "  cloneproject gh kulesh/example"
        echo "  cloneproject https://github.com/kulesh/example.git"
        echo "  cloneproject git@github.com:kulesh/example.git"
        return 1
    fi
    
    local github_url="${url_info%|*}"
    local repo_name="${url_info#*|}"
    local project_path="${MISE_PROJECTS_DIR}/${repo_name}"
    
    # Check if project already exists
    if [[ -d "$project_path" ]]; then
        echo "❌ Error: Project '$repo_name' already exists at $project_path"
        echo "   Use 'workon $repo_name' to switch to existing project"
        echo "   Or choose a different approach to update the existing project"
        return 1
    fi
    
    echo "Creating base project and cloning from GitHub..."
    echo "📦 Repository: $github_url"
    echo "📁 Local name: $repo_name"
    
    # Create base project using mkproject
    if ! mkproject "$repo_name" base; then
        echo "❌ Error: Failed to create base project"
        return 1
    fi
    
    # We should now be in the project directory from mkproject
    local current_dir="$PWD"
    if [[ "$current_dir" != "$project_path" ]]; then
        echo "❌ Error: Unexpected directory after mkproject"
        return 1
    fi
    
    # Clone repository content
    if clone_repository_content "$github_url" "$repo_name"; then
        echo "✅ Project '$repo_name' cloned successfully"
        echo "📁 Location: $project_path"
        echo "🔗 Remote: $github_url"
        echo ""
        echo "Use 'workon $repo_name' to return to this project anytime"
    else
        return 1
    fi
}

# Change to a specific project
# Usage: workon <project_name> [-s|--sandbox]
function workon() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: workon <project_name> [-s]"
        echo ""
        echo "Options:"
        echo "  -s, --sandbox  Run in sandboxed environment (restricted filesystem access)"
        return 1
    fi

    local projname=""
    local use_sandbox=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --sandbox|-s)
                use_sandbox=true
                shift
                ;;
            -*)
                echo "Unknown option: $1"
                return 1
                ;;
            *)
                if [[ -z "$projname" ]]; then
                    projname="$1"
                fi
                shift
                ;;
        esac
    done

    local projdir="${MISE_PROJECTS_DIR}/${projname}"

    if [[ ! -d "$projdir" ]]; then
        echo "Project $projname not found in $MISE_PROJECTS_DIR"
        return 1
    fi

    if [[ ! -e "$projdir/.mise.toml" && ! -e "$projdir/.tool-versions" ]]; then
        echo "Not a mise project: $projdir"
        return 1
    fi

    # First-time sandbox setup: create marker and add hooks
    if [[ "$use_sandbox" == true && ! -f "$projdir/.sandbox" ]]; then
        touch "$projdir/.sandbox"
        _sandbox_add_hooks "$projdir"
        echo "Sandbox enabled for $projname"
    fi

    # Auto-enable sandbox if .sandbox marker exists
    if [[ -f "$projdir/.sandbox" ]]; then
        use_sandbox=true
    fi

    if [[ "$use_sandbox" == true ]]; then
        _workon_sandboxed "$projname" "$projdir"
        local sandbox_exit=$?
        if [[ $sandbox_exit -ne 42 ]]; then
            exit $sandbox_exit  # Explicit exit - close terminal
        fi
        # Implicit exit (42) - already cd'd to destination by _workon_sandboxed
    else
        if safe_cd "$projdir"; then
            echo "Now working on $projname"
        fi
    fi
}

# List all projects with metadata
lsprojects() {
    local filter_type=""
    local show_tools=false

    # Colors
    local cyan='\033[36m'
    local green='\033[32m'
    local yellow='\033[33m'
    local magenta='\033[35m'
    local dim='\033[2m'
    local bold='\033[1m'
    local reset='\033[0m'

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type=*)
                filter_type="${1#*=}"
                if [[ "$filter_type" != "cloned" && "$filter_type" != "created" ]]; then
                    echo "❌ Error: Invalid type filter. Use 'cloned' or 'created'"
                    return 1
                fi
                ;;
            --tools)
                show_tools=true
                ;;
            *)
                echo "Usage: lsprojects [--type=cloned|created] [--tools]"
                return 1
                ;;
        esac
        shift
    done

    if [[ ! -d "$MISE_PROJECTS_DIR" ]]; then
        echo "Projects directory not found: $MISE_PROJECTS_DIR"
        return 1
    fi

    echo -e "${bold}📁 Projects${reset} ${dim}in ${MISE_PROJECTS_DIR}${reset}"
    echo ""

    local project_count=0
    local cloned_count=0
    local created_count=0
    local sandboxed_count=0

    # Process each directory in projects folder
    for projdir in "$MISE_PROJECTS_DIR"/*(N/); do
        [[ ! -d "$projdir" ]] && continue

        local projname="${projdir:t}"

        # Check if it's a valid mise project
        if [[ ! -e "$projdir/.mise.toml" && ! -e "$projdir/.tool-versions" ]]; then
            continue
        fi

        # Determine project type (cloned vs created)
        local project_type=""
        local remote_info=""
        local type_icon=""

        local github_info=$(get_github_repo_info "$projdir")
        if [[ -n "$github_info" ]]; then
            project_type="cloned"
            remote_info="$github_info"
            type_icon="↙"
            ((cloned_count++))
        else
            project_type="created"
            remote_info="local"
            type_icon="✦"
            ((created_count++))
        fi

        # Apply filter if specified
        if [[ -n "$filter_type" && "$filter_type" != "$project_type" ]]; then
            continue
        fi

        ((project_count++))

        # Get last modified time
        local last_modified=$(get_last_modified "$projdir" "short")

        # Check sandbox status
        local sandbox_indicator=""
        if [[ -f "$projdir/.sandbox" ]]; then
            sandbox_indicator="🔒"
            ((sandboxed_count++))
        fi

        # Display project info with colors
        printf "${cyan}%-24s${reset}" "$projname"
        printf "%-3s" "$sandbox_indicator"

        if [[ "$project_type" == "cloned" ]]; then
            printf "${green}${type_icon} ${remote_info}${reset}"
        else
            printf "${yellow}${type_icon} ${remote_info}${reset}"
        fi

        if [[ -n "$last_modified" ]]; then
            printf " ${dim}%s${reset}" "$last_modified"
        fi

        echo ""

        # Show mise tools if requested (use -C to avoid triggering mise hooks)
        if [[ "$show_tools" == true ]]; then
            local tools_output=$(mise -C "$projdir" ls --current 2>/dev/null | grep -v "No tools" | head -3)
            if [[ -n "$tools_output" ]]; then
                echo "$tools_output" | sed 's/^/    /'
            fi
            echo ""
        fi
    done

    # Summary
    echo ""
    if [[ "$project_count" -eq 0 ]]; then
        if [[ -n "$filter_type" ]]; then
            echo "No $filter_type projects found"
        else
            echo "No mise projects found"
        fi
    else
        echo -e "${bold}📊 Summary${reset}"
        if [[ -z "$filter_type" ]]; then
            echo -e "   ${dim}Total${reset}     ${bold}$project_count${reset} projects"
            echo -e "   ${green}↙ Cloned${reset}   $cloned_count"
            echo -e "   ${yellow}✦ Created${reset}  $created_count"
            echo -e "   ${magenta}🔒 Sandbox${reset}  $sandboxed_count"
        else
            echo "   $project_type projects: $project_count"
        fi
    fi
}

# Update a cloned project by pulling latest changes
updateproject() {
    local project_name="$1"
    local project_dir=""
    local original_dir="$PWD"
    
    # Determine which project to update
    if [[ -n "$project_name" ]]; then
        # Project name specified
        project_dir="${MISE_PROJECTS_DIR}/${project_name}"
        
        if [[ ! -d "$project_dir" ]]; then
            echo "❌ Error: Project '$project_name' not found in $MISE_PROJECTS_DIR"
            return 1
        fi
        
        if [[ ! -e "$project_dir/.mise.toml" && ! -e "$project_dir/.tool-versions" ]]; then
            echo "❌ Error: '$project_name' is not a mise project"
            return 1
        fi
        
        if ! safe_cd "$project_dir"; then
            return 1
        fi
    else
        # No project specified, use current directory
        local mise_dir=$(get_mise_root)
        
        if [[ -z "$mise_dir" ]]; then
            echo "❌ Error: Not in a mise project and no project name specified"
            echo "Usage: updateproject [project_name]"
            return 1
        fi
        
        project_dir="$mise_dir"
        project_name="${mise_dir:t}"
        if ! safe_cd "$project_dir"; then
            return 1
        fi
    fi
    
    # Check if it's a git repository
    if [[ ! -d ".git" ]]; then
        echo "❌ Error: '$project_name' is not a git repository"
        echo "   This command only works with cloned projects"
        safe_cd "$original_dir"
        return 1
    fi
    
    # Check if it has a remote
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$remote_url" ]]; then
        echo "❌ Error: '$project_name' has no remote origin"
        echo "   This appears to be a local git repository"
        safe_cd "$original_dir"
        return 1
    fi
    
    echo "Updating project: $project_name"
    echo "Remote: $remote_url"
    echo ""
    
    # Get current branch
    local current_branch=$(git branch --show-current 2>/dev/null)
    if [[ -z "$current_branch" ]]; then
        echo "❌ Error: Unable to determine current branch"
        safe_cd "$original_dir"
        return 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo "⚠️  Warning: You have uncommitted changes"
        echo ""
        git status --porcelain
        echo ""
        echo "Commit or stash your changes before updating"
        safe_cd "$original_dir"
        return 1
    fi
    
    # Fetch latest changes
    echo "🔍 Checking for updates..."
    if ! git fetch origin "$current_branch" 2>/dev/null; then
        echo "❌ Error: Failed to fetch from remote"
        echo "   Check your network connection and remote access"
        safe_cd "$original_dir"
        return 1
    fi
    
    # Check if there are updates available
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse "origin/$current_branch" 2>/dev/null)
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
        echo "✅ Already up to date"
        safe_cd "$original_dir"
        return 0
    fi
    
    # Show what will be updated
    echo "📋 Changes to be pulled:"
    echo ""
    git log --oneline --graph "$current_branch..origin/$current_branch" | head -10
    echo ""
    
    local commit_count=$(git rev-list --count "$current_branch..origin/$current_branch")
    echo "📊 $commit_count new commit(s) available"
    echo ""
    
    # Ask for confirmation (in interactive mode)
    if [[ -t 0 ]]; then
        echo -n "Pull these changes? [Y/n] "
        read -r response
        case "$response" in
            [nN]|[nN][oO])
                echo "Update cancelled"
                safe_cd "$original_dir"
                return 0
                ;;
        esac
    fi
    
    # Pull the changes
    echo "⬇️  Pulling changes..."
    if git pull origin "$current_branch"; then
        echo ""
        echo "✅ Successfully updated '$project_name'"
        
        # Show summary of what was pulled
        echo "📋 Summary:"
        git log --oneline -n 3 "$local_commit.." | sed 's/^/   /'
        
        # Trust mise config if it changed
        if git diff --name-only "$local_commit.." | grep -q "\.mise\.toml"; then
            echo ""
            echo "🔧 Mise configuration changed, trusting new config..."
            mise trust .mise.toml
        fi
        
    else
        echo "❌ Error: Failed to pull changes"
        echo "   You may need to resolve conflicts manually"
        safe_cd "$original_dir"
        return 1
    fi
    
    safe_cd "$original_dir"
}

# Display git repository information
function show_git_info() {
    local project_name="$1"

    # Colors
    local cyan='\033[36m'
    local green='\033[32m'
    local magenta='\033[35m'
    local yellow='\033[33m'
    local red='\033[31m'
    local dim='\033[2m'
    local bold='\033[1m'
    local reset='\033[0m'

    if [[ ! -d ".git" ]]; then
        echo -e "${dim}Git: not a repository${reset}"
        return 0
    fi

    echo -e "${bold} Git${reset}"

    # Current branch and commit
    local current_branch=$(git branch --show-current 2>/dev/null)
    local current_commit=$(git rev-parse --short HEAD 2>/dev/null)

    if [[ -n "$current_branch" ]]; then
        echo -e "  ${magenta}⎇ $current_branch${reset} ${dim}($current_commit)${reset}"
    fi

    # Remote information
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -n "$remote_url" ]]; then
        echo -e "  ${green}↗ $remote_url${reset}"

        # Check if we're ahead/behind remote
        if git show-ref --verify --quiet "refs/remotes/origin/$current_branch"; then
            local ahead=$(git rev-list --count "origin/$current_branch..HEAD" 2>/dev/null)
            local behind=$(git rev-list --count "HEAD..origin/$current_branch" 2>/dev/null)

            if [[ "$ahead" -gt 0 ]] || [[ "$behind" -gt 0 ]]; then
                local status_parts=()
                if [[ "$ahead" -gt 0 ]]; then
                    status_parts+=("${green}↑$ahead${reset}")
                fi
                if [[ "$behind" -gt 0 ]]; then
                    status_parts+=("${red}↓$behind${reset}")
                fi
                echo -e "  $(IFS=' '; echo "${status_parts[*]}")"
            else
                echo -e "  ${dim}✓ up to date${reset}"
            fi
        fi
    else
        echo -e "  ${dim}↗ (no remote)${reset}"
    fi

    # Working directory status
    local git_status=$(git status --porcelain 2>/dev/null)
    if [[ -n "$git_status" ]]; then
        echo ""
        echo -e "${bold}  Changes${reset}"

        # Count different types of changes
        local modified=$(echo "$git_status" | grep "^ M" | wc -l | tr -d ' ')
        local added=$(echo "$git_status" | grep "^A" | wc -l | tr -d ' ')
        local deleted=$(echo "$git_status" | grep "^ D" | wc -l | tr -d ' ')
        local untracked=$(echo "$git_status" | grep "^??" | wc -l | tr -d ' ')
        local staged=$(echo "$git_status" | grep "^[MADR]" | wc -l | tr -d ' ')

        local changes=()
        if [[ "$staged" -gt 0 ]]; then
            changes+=("${green}$staged staged${reset}")
        fi
        if [[ "$modified" -gt 0 ]]; then
            changes+=("${yellow}$modified modified${reset}")
        fi
        if [[ "$added" -gt 0 && "$staged" -eq 0 ]]; then
            changes+=("${green}$added added${reset}")
        fi
        if [[ "$deleted" -gt 0 ]]; then
            changes+=("${red}$deleted deleted${reset}")
        fi
        if [[ "$untracked" -gt 0 ]]; then
            changes+=("${cyan}$untracked untracked${reset}")
        fi

        if [[ ${#changes[@]} -gt 0 ]]; then
            echo -e "  $(IFS=', '; echo "${changes[*]}")"
        fi

        # Show first few changed files
        echo "$git_status" | head -5 | while read line; do
            local status_code="${line:0:2}"
            local filename="${line:3}"
            local color=""
            local icon=""

            case "$status_code" in
                " M") color="$yellow"; icon="~" ;;
                "A "|"M ") color="$green"; icon="+" ;;
                " D") color="$red"; icon="-" ;;
                "??") color="$cyan"; icon="?" ;;
                *) color="$dim"; icon="•" ;;
            esac

            echo -e "    ${color}${icon} ${filename}${reset}"
        done

        # Show if there are more files
        local total_files=$(echo "$git_status" | wc -l | tr -d ' ')
        if [[ "$total_files" -gt 5 ]]; then
            echo -e "    ${dim}... and $((total_files - 5)) more${reset}"
        fi
    else
        echo -e "  ${dim}✓ working directory clean${reset}"
    fi
}

# Show recent git activity
function show_git_activity() {
    # Colors
    local dim='\033[2m'
    local bold='\033[1m'
    local reset='\033[0m'

    if [[ ! -d ".git" ]]; then
        return 0
    fi

    echo -e "${bold}📜 Recent${reset}"
    if git log --oneline -n 3 2>/dev/null | head -3 >/dev/null; then
        git log --format="  %C(dim)%h%C(reset) %s" -n 3 2>/dev/null
    else
        echo -e "  ${dim}(no commits yet)${reset}"
    fi
}

# Show detailed information about the current mise project
function showproject() {
    # Colors
    local cyan='\033[36m'
    local green='\033[32m'
    local magenta='\033[35m'
    local yellow='\033[33m'
    local dim='\033[2m'
    local bold='\033[1m'
    local reset='\033[0m'

    local mise_dir=$(get_mise_root)

    if [[ -z "$mise_dir" ]]; then
        echo "Not in a mise project"
        return 1
    fi

    local project_name="${mise_dir:t}"
    local last_modified=$(get_last_modified "$mise_dir" "full")

    # Header
    echo -e "${bold}${cyan}$project_name${reset}"
    echo -e "${dim}$mise_dir${reset}"
    echo ""

    # Status line
    if [[ -f "$mise_dir/.sandbox" ]]; then
        echo -e "  ${green}🔒 Sandboxed${reset}"
    fi
    if [[ -n "$last_modified" ]]; then
        echo -e "  ${dim}Modified: $last_modified${reset}"
    fi
    echo ""

    # Show mise tools
    echo -e "${bold}⚙ Tools${reset}"
    local tools_output=$(mise ls --current 2>/dev/null)
    if [[ -n "$tools_output" && "$tools_output" != *"No tools"* ]]; then
        echo "$tools_output" | sed 's/^/  /'
    else
        echo -e "  ${dim}(none configured)${reset}"
    fi
    echo ""

    # Git information
    show_git_info "$project_name"
    echo ""

    # Recent activity
    show_git_activity
}

# Check for git-related warnings before removal
function check_removal_warnings() {
    local project_path="$1"
    local project_name="$2"
    local has_warnings=false
    
    if [[ ! -d "$project_path/.git" ]]; then
        return 0
    fi
    
    local original_dir="$PWD"
    if ! safe_cd "$project_path"; then
        return 1
    fi
    
    local git_status=$(git status --porcelain 2>/dev/null)
    if [[ -n "$git_status" ]]; then
        has_warnings=true
        echo "⚠️  Warning: Project has uncommitted changes:"
        echo "$git_status" | head -5 | sed 's/^/   /'
        local total_files=$(echo "$git_status" | wc -l | tr -d ' ')
        if [[ "$total_files" -gt 5 ]]; then
            echo "   ... and $((total_files - 5)) more"
        fi
    fi
    
    # Check if it's a cloned repo
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -n "$remote_url" ]]; then
        echo "Git remote: $remote_url"
        
        # Check if ahead of remote
        local current_branch=$(git branch --show-current 2>/dev/null)
        if [[ -n "$current_branch" ]] && git show-ref --verify --quiet "refs/remotes/origin/$current_branch"; then
            local ahead=$(git rev-list --count "origin/$current_branch..HEAD" 2>/dev/null)
            if [[ "$ahead" -gt 0 ]]; then
                has_warnings=true
                echo "⚠️  Warning: $ahead unpushed commit(s)"
            fi
        fi
    fi
    
    safe_cd "$original_dir"
    
    if [[ "$has_warnings" == true ]]; then
        return 0  # Has warnings
    else
        return 1  # No warnings
    fi
}

# Remove a project with optional archiving
rmproject() {
    local project_name="$1"
    local archive_mode=true  # Default to archive mode
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --delete|--force)
                archive_mode=false
                shift
                ;;
            --archive)
                archive_mode=true
                shift
                ;;
            -*)
                echo "❌ Error: Unknown option '$1'"
                echo "Usage: rmproject <project_name> [--delete]"
                echo "  Default: Archive project to .archive/ directory"
                echo "  --delete  Permanently delete instead of archiving"
                return 1
                ;;
            *)
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$project_name" ]]; then
        echo "Usage: rmproject <project_name> [--delete]"
        echo "  Default: Archive project to .archive/ directory"
        echo "  --delete  Permanently delete instead of archiving"
        return 1
    fi
    
    local project_path="${MISE_PROJECTS_DIR}/${project_name}"
    
    # Check if project exists
    if [[ ! -d "$project_path" ]]; then
        echo "❌ Error: Project '$project_name' not found in $MISE_PROJECTS_DIR"
        return 1
    fi
    
    # Check if it's a valid mise project
    if [[ ! -e "$project_path/.mise.toml" && ! -e "$project_path/.tool-versions" ]]; then
        echo "❌ Error: '$project_name' is not a mise project"
        return 1
    fi
    
    # Show project info
    echo "Project to remove: $project_name"
    echo "Location: $project_path"
    
    # Check for git-related warnings
    local has_uncommitted=false
    if check_removal_warnings "$project_path" "$project_name"; then
        has_uncommitted=true
    fi
    
    echo ""
    
    if [[ "$archive_mode" == true ]]; then
        # Archive mode (default)
        local archive_dir="${MISE_PROJECTS_DIR}/.archive"
        local archive_path="${archive_dir}/${project_name}"
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        
        # Create archive directory if it doesn't exist
        mkdir -p "$archive_dir"
        
        # If archive already exists, add timestamp
        if [[ -d "$archive_path" ]]; then
            archive_path="${archive_dir}/${project_name}_${timestamp}"
        fi
        
        echo "This will archive the project to: $archive_path"
        
        if [[ "$has_uncommitted" == true ]]; then
            echo "✅ Uncommitted changes will be preserved in archive"
        fi
        
    else
        # Delete mode (explicit --delete flag)
        echo "This will permanently delete the project directory"
        echo "⚠️  This action cannot be undone!"
        
        if [[ "$has_uncommitted" == true ]]; then
            echo "⚠️  All uncommitted changes will be lost!"
        fi
    fi
    
    echo ""
    
    # Ask for confirmation (in interactive mode)
    if [[ -t 0 ]]; then
        if [[ "$archive_mode" == true ]]; then
            echo -n "Archive this project? [Y/n] "
        else
            echo -n "Permanently delete this project? [y/N] "
        fi
        
        read -r response
        if [[ "$archive_mode" == true ]]; then
            # Archive is default, so accept Y/y/enter as yes, everything else as no
            case "$response" in
                [nN]|[nN][oO])
                    echo "Operation cancelled"
                    return 0
                    ;;
            esac
        else
            # Delete requires explicit confirmation
            case "$response" in
                [yY]|[yY][eE][sS])
                    # Proceed with deletion
                    ;;
                *)
                    echo "Operation cancelled"
                    return 0
                    ;;
            esac
        fi
    fi
    
    # Perform the operation
    if [[ "$archive_mode" == true ]]; then
        echo "📦 Archiving project..."
        if mv "$project_path" "$archive_path"; then
            echo "✅ Project '$project_name' archived to:"
            echo "   $archive_path"
            echo ""
            echo "To restore: mv '$archive_path' '$project_path'"
        else
            echo "❌ Error: Failed to archive project"
            return 1
        fi
    else
        echo "🗑️  Deleting project..."
        if rm -rf "$project_path"; then
            echo "✅ Project '$project_name' deleted"
        else
            echo "❌ Error: Failed to delete project"
            return 1
        fi
    fi
    
    # If we're currently in the deleted/archived project, cd to projects directory
    local current_dir="$PWD"
    if [[ "$current_dir" == "$project_path"* ]]; then
        echo "Moving out of deleted project directory..."
        safe_cd "$MISE_PROJECTS_DIR"
    fi
}

# Setup zsh completion for workon (projects + sandbox flags)
function _mise_project_completion() {
  local -a projects opts

  # Define sandbox options
  opts=(
    '--sandbox:Enter sandboxed environment'
    '-s:Enter sandboxed environment (short)'
  )

  # If current word starts with -, complete options
  if [[ ${words[CURRENT]} == -* ]]; then
    _describe 'options' opts
    return
  fi

  # Otherwise complete project names
  if [[ -d "$MISE_PROJECTS_DIR" ]]; then
    for projdir in "$MISE_PROJECTS_DIR"/*(N/); do
      local projname=${projdir:t}
      if [[ -e "$projdir/.mise.toml" || -e "$projdir/.tool-versions" ]]; then
        projects+=("$projname")
      fi
    done
  fi

  _describe 'mise projects' projects
}

# Setup zsh completion for updateproject (only cloned projects)
function _updateproject_completion() {
  local -a cloned_projects
  
  if [[ -d "$MISE_PROJECTS_DIR" ]]; then
    for projdir in "$MISE_PROJECTS_DIR"/*(N/); do
      local projname=${projdir:t}
      
      # Check if it's a valid mise project
      if [[ -e "$projdir/.mise.toml" || -e "$projdir/.tool-versions" ]]; then
        # Check if it's a git repo with remote
        if [[ -d "$projdir/.git" ]]; then
          local remote_url=$(get_git_remote_info "$projdir")
          if [[ -n "$remote_url" ]]; then
            cloned_projects+=("$projname")
          fi
        fi
      fi
    done
  fi
  
  _describe 'cloned projects' cloned_projects
}

# Setup zsh completion for rmproject
function _rmproject_completion() {
  local -a projects
  
  if [[ -d "$MISE_PROJECTS_DIR" ]]; then
    for projdir in "$MISE_PROJECTS_DIR"/*(N/); do
      local projname=${projdir:t}
      if [[ -e "$projdir/.mise.toml" || -e "$projdir/.tool-versions" ]]; then
        projects+=("$projname")
      fi
    done
  fi
  
  _describe 'mise projects' projects
}

# Register completions
if [[ -n "$ZSH_VERSION" ]]; then
  # Only if zsh completion is initialized
  if whence compdef &>/dev/null; then
    compdef _mise_project_completion workon
    compdef _updateproject_completion updateproject
    compdef _rmproject_completion rmproject
  fi
fi

# Create projects directory if it doesn't exist
[[ -d "$MISE_PROJECTS_DIR" ]] || mkdir -p "$MISE_PROJECTS_DIR"

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
