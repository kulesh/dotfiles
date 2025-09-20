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

# Change to the mise project directory
function cdproject() {
  local mise_dir=$(get_mise_root)
  
  if [[ -z "$mise_dir" ]]; then
    echo "Not in a mise project"
    cd "$HOME_DIR"
    return 1
  fi

  cd "$mise_dir"
}

# Top-level function to list available project types
list_project_types() {
    echo "Available project types:"
    if mise tasks ls 2>/dev/null | grep "mkproject:" | sed 's/mkproject:/  - /'; then
        return 0
    else
        echo "  (none found)"
        return 1
    fi
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
        cd "$project_path"
    else
        echo "❌ Error: Failed to create $project_type project"
        echo "   ⚠️  Incomplete project left at: $project_path"
        echo "   You may want to manually remove it or investigate the issue"
        return 1
    fi
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
    
    local github_url
    local repo_name
    
    # Parse input and extract GitHub URL and repo name
    if [[ "$first_arg" == "gh" && -n "$second_arg" ]]; then
        # Handle "gh user/repo" format (two arguments)
        if [[ "$second_arg" =~ ^([^/]+)/([^/]+)$ ]]; then
            local user="${match[1]}"
            local repo="${match[2]}"
            github_url="git@github.com:${user}/${repo}.git"
            repo_name="$repo"
        else
            echo "❌ Error: Invalid repo format. Expected 'user/repo'"
            echo "Example: cloneproject gh kulesh/example"
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
        echo "❌ Error: Invalid format. Use 'gh user/repo' or full GitHub URL"
        echo "Examples:"
        echo "  cloneproject gh kulesh/example"
        echo "  cloneproject https://github.com/kulesh/example.git"
        echo "  cloneproject git@github.com:kulesh/example.git"
        return 1
    fi
    
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
    
    echo "✅ Project '$repo_name' cloned successfully"
    echo "📁 Location: $project_path"
    echo "🔗 Remote: $github_url"
    echo ""
    echo "Use 'workon $repo_name' to return to this project anytime"
}

# Change to a specific project
function workon() {
  if [[ $# -lt 1 ]]; then
    echo "Project name is required: workon <project_name>"
    return 1
  fi

  local projname="$1"
  local projdir="${MISE_PROJECTS_DIR}/${projname}"
  
  if [[ ! -d "$projdir" ]]; then
    echo "Project $projname not found in $MISE_PROJECTS_DIR"
    return 1
  fi

  if [[ ! -e "$projdir/.mise.toml" && ! -e "$projdir/.tool-versions" ]]; then
    echo "Not a mise project: $projdir"
    return 1
  fi

  cd "$projdir"
  echo "Now working on $projname"
}

# Show the current mise project
function showproject() {
  local mise_dir=$(get_mise_root)
  
  if [[ -z "$mise_dir" ]]; then
    echo "Not in a mise project"
    return 1
  fi

  echo "Current mise project: ${mise_dir:t}"
  echo "Project root: $mise_dir"
  
  # Show active tools
  echo "Active tools:"
  mise ls | grep -v "No actively used tools found"
}

# Setup zsh completion
function _mise_project_completion() {
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
  fi
fi

# Create projects directory if it doesn't exist
[[ -d "$MISE_PROJECTS_DIR" ]] || mkdir -p "$MISE_PROJECTS_DIR"
