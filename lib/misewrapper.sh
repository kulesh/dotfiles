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

# Generate a project-specific sandbox profile by expanding variables in template
function _sandbox_generate_profile() {
    local project_dir="$1"
    local profile_template="${SANDBOX_PROFILES_DIR}/default.sb"

    if [[ ! -f "$profile_template" ]]; then
        echo "Error: Sandbox profile template not found: $profile_template" >&2
        return 1
    fi

    # Expand variables in the profile
    sed -e "s|\${HOME}|${HOME}|g" \
        -e "s|\${PROJECT_DIR}|${project_dir}|g" \
        "$profile_template"
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

# Add mise hooks for auto-enter/exit sandbox on cd
function _sandbox_add_hooks() {
    local projdir="$1"
    local mise_file="$projdir/.mise.toml"
    local projname=$(basename "$projdir")

    # Skip if hooks already exist
    if grep -q '^\[hooks\]' "$mise_file" 2>/dev/null; then
        echo "Hooks already exist in $mise_file"
        return 0
    fi

    # Append hooks to .mise.toml
    # Note: Check for marker file (mise hooks don't inherit env vars)
    cat >> "$mise_file" << EOF

[hooks]
enter = 'if [ ! -f /tmp/.sandbox-entering ] && [ -f ".sandbox" ]; then zsh -c "source ~/.dotfiles/lib/misewrapper.sh && _workon_sandboxed ${projname} ${projdir}"; fi'
leave = '[ -n "\$IN_SANDBOX" ] && exit 0 || true'
EOF

    echo "Sandbox hooks added to $mise_file"
}

# Enter sandboxed environment using macOS sandbox-exec
function _workon_sandboxed() {
    local projname="$1"
    local projdir="$2"

    # Prevent nested sandboxes (return 0 to avoid mise hook warnings)
    if [[ -n "$IN_SANDBOX" ]]; then
        return 0
    fi

    # Generate profile with expanded variables
    # Note: separate declaration from assignment so $? isn't reset by 'local'
    local profile
    if ! profile=$(_sandbox_generate_profile "$projdir"); then
        return 1
    fi

    _sandbox_log "$projname" "ENTER" "pid=$$ profile=default dir=$projdir"

    echo "Entering sandboxed environment for: $projname"
    echo "  Project (r/w): $projdir"
    echo "  Tools (r/o):   ~/.local/share/mise, /opt/homebrew"
    echo "  Network:       outbound allowed"
    echo "  Exit with:     exit or Ctrl-D"
    echo ""

    # Save original directory to restore after sandbox exits
    local original_dir="$PWD"

    # Create marker to block mise hook re-entry (mise hooks don't inherit env vars)
    touch "/tmp/.sandbox-entering"

    # Launch sandboxed shell with sandbox env vars (for starship indicator and chpwd hook)
    # Pass TERM to ensure proper terminal handling (backspace, etc.)
    cd "$projdir"
    sandbox-exec -p "$profile" env TERM="$TERM" IN_SANDBOX=1 SANDBOX_PROJECT="$projname" SANDBOX_PROJECT_DIR="$projdir" /bin/zsh -i
    local exit_code=$?

    # Clean up marker
    rm -f "/tmp/.sandbox-entering"

    # Restore original directory
    cd "$original_dir"

    _sandbox_log "$projname" "EXIT" "pid=$$ code=$exit_code"

    echo ""
    echo "Exited sandbox for $projname (code: $exit_code)"

    return $exit_code
}

# Extract git remote information
function get_git_remote_info() {
  local repo_dir="$1"
  local current_dir="$PWD"
  
  if [[ ! -d "$repo_dir/.git" ]]; then
    return 1
  fi
  
  if ! safe_cd "$repo_dir"; then
    return 1
  fi
  
  local remote_url=$(git remote get-url origin 2>/dev/null)
  safe_cd "$current_dir"
  
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
    
    echo "Projects in $MISE_PROJECTS_DIR"
    echo ""
    
    local project_count=0
    local cloned_count=0
    local created_count=0
    
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
        
        local github_info=$(get_github_repo_info "$projdir")
        if [[ -n "$github_info" ]]; then
            project_type="cloned"
            remote_info="$github_info"
            ((cloned_count++))
        else
            project_type="created"
            remote_info="local"
            ((created_count++))
        fi
        
        # Apply filter if specified
        if [[ -n "$filter_type" && "$filter_type" != "$project_type" ]]; then
            continue
        fi
        
        ((project_count++))
        
        # Get last modified time
        local last_modified=$(get_last_modified "$projdir" "short")
        
        # Display project info in ls -l style
        printf "%-20s %s" "$projname" "$remote_info"
        
        if [[ -n "$last_modified" ]]; then
            printf " %s" "$last_modified"
        fi
        
        echo ""
        
        # Show mise tools if requested
        if [[ "$show_tools" == true ]]; then
            local current_dir="$PWD"
            if safe_cd "$projdir"; then
                local tools_output=$(mise ls --current 2>/dev/null | grep -v "No tools" | head -3)
                if [[ -n "$tools_output" ]]; then
                    echo "$tools_output" | sed 's/^/    /'
                fi
                echo ""
                safe_cd "$current_dir"
            fi
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
        echo "📊 Summary:"
        if [[ -z "$filter_type" ]]; then
            echo "   Total: $project_count projects"
            echo "   Cloned: $cloned_count"
            echo "   Created: $created_count"
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
    
    if [[ ! -d ".git" ]]; then
        echo "Git: not a repository"
        return 0
    fi
    
    echo "Git repository:"
    
    # Current branch and commit
    local current_branch=$(git branch --show-current 2>/dev/null)
    local current_commit=$(git rev-parse --short HEAD 2>/dev/null)
    
    if [[ -n "$current_branch" ]]; then
        echo "  Branch: $current_branch"
    fi
    
    if [[ -n "$current_commit" ]]; then
        echo "  Commit: $current_commit"
    fi
    
    # Remote information
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -n "$remote_url" ]]; then
        echo "  Remote: $remote_url"
        
        # Check if we're ahead/behind remote
        if git show-ref --verify --quiet "refs/remotes/origin/$current_branch"; then
            local ahead=$(git rev-list --count "origin/$current_branch..HEAD" 2>/dev/null)
            local behind=$(git rev-list --count "HEAD..origin/$current_branch" 2>/dev/null)
            
            if [[ "$ahead" -gt 0 ]] || [[ "$behind" -gt 0 ]]; then
                local status_msg=""
                if [[ "$ahead" -gt 0 ]]; then
                    status_msg="$ahead ahead"
                fi
                if [[ "$behind" -gt 0 ]]; then
                    if [[ -n "$status_msg" ]]; then
                        status_msg="$status_msg, $behind behind"
                    else
                        status_msg="$behind behind"
                    fi
                fi
                echo "  Status: $status_msg"
            else
                echo "  Status: up to date"
            fi
        fi
    else
        echo "  Remote: (none configured)"
    fi
    
    # Working directory status
    local git_status=$(git status --porcelain 2>/dev/null)
    if [[ -n "$git_status" ]]; then
        echo "  Working directory:"
        
        # Count different types of changes
        local modified=$(echo "$git_status" | grep "^ M" | wc -l | tr -d ' ')
        local added=$(echo "$git_status" | grep "^A" | wc -l | tr -d ' ')
        local deleted=$(echo "$git_status" | grep "^ D" | wc -l | tr -d ' ')
        local untracked=$(echo "$git_status" | grep "^??" | wc -l | tr -d ' ')
        local staged=$(echo "$git_status" | grep "^[MADR]" | wc -l | tr -d ' ')
        
        local changes=()
        if [[ "$staged" -gt 0 ]]; then
            changes+=("$staged staged")
        fi
        if [[ "$modified" -gt 0 ]]; then
            changes+=("$modified modified")
        fi
        if [[ "$added" -gt 0 && "$staged" -eq 0 ]]; then
            changes+=("$added added")
        fi
        if [[ "$deleted" -gt 0 ]]; then
            changes+=("$deleted deleted")
        fi
        if [[ "$untracked" -gt 0 ]]; then
            changes+=("$untracked untracked")
        fi
        
        if [[ ${#changes[@]} -gt 0 ]]; then
            local change_summary=$(IFS=', '; echo "${changes[*]}")
            echo "    $change_summary"
        fi
        
        # Show first few changed files
        echo "$git_status" | head -5 | while read line; do
            local status_code="${line:0:2}"
            local filename="${line:3}"
            local status_desc=""
            
            case "$status_code" in
                " M") status_desc="modified" ;;
                "A ") status_desc="added" ;;
                " D") status_desc="deleted" ;;
                "??") status_desc="untracked" ;;
                "M ") status_desc="staged" ;;
                *) status_desc="changed" ;;
            esac
            
            echo "    $status_desc: $filename"
        done
        
        # Show if there are more files
        local total_files=$(echo "$git_status" | wc -l | tr -d ' ')
        if [[ "$total_files" -gt 5 ]]; then
            echo "    ... and $((total_files - 5)) more"
        fi
    else
        echo "  Working directory: clean"
    fi
}

# Show recent git activity
function show_git_activity() {
    if [[ ! -d ".git" ]]; then
        return 0
    fi
    
    echo "Recent commits:"
    if git log --oneline -n 3 2>/dev/null | head -3 >/dev/null; then
        git log --oneline -n 3 2>/dev/null | sed 's/^/  /'
    else
        echo "  (no commits yet)"
    fi
}

# Show detailed information about the current mise project
function showproject() {
    local mise_dir=$(get_mise_root)
    
    if [[ -z "$mise_dir" ]]; then
        echo "Not in a mise project"
        return 1
    fi

    local project_name="${mise_dir:t}"
    local last_modified=$(get_last_modified "$mise_dir" "full")
    
    echo "Project: $project_name"
    echo "Location: $mise_dir"
    if [[ -n "$last_modified" ]]; then
        echo "Modified: $last_modified"
    fi
    echo ""
    
    # Show mise tools
    echo "Mise tools:"
    local tools_output=$(mise ls --current 2>/dev/null)
    if [[ -n "$tools_output" && "$tools_output" != *"No tools"* ]]; then
        echo "$tools_output" | sed 's/^/  /'
    else
        echo "  (none configured)"
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
            echo "Left sandbox project, exiting..."
            exit 0
        fi
    }
    chpwd_functions+=(_sandbox_chpwd)
fi