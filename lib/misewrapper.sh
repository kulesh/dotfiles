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
    local mkproject_tasks=$(echo "$tasks_output" | grep "mkproject:")
    
    if [[ -z "$mkproject_tasks" ]]; then
        echo "  (none found)"
        return 1
    fi
    
    # Parse the output and reformat
    echo "$mkproject_tasks" | while IFS= read -r line; do
        # Parse the mise tasks output format: "Name Description Source"
        # Extract task name (remove mkproject: prefix) and description
        local task_name=$(echo "$line" | awk '{print $1}' | sed 's/mkproject://')
        local description=$(echo "$line" | awk '{$1=""; $NF=""; print $0}' | sed 's/^ *//; s/ *$//')
        
        # If no description, show generic text
        if [[ -z "$description" || "$description" == "$line" ]]; then
            description="Project template"
        fi
        
        # Format with consistent alignment (assuming max 15 chars for template name)
        printf "  %-15s %s\n" "$task_name" "$description"
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
        
        if [[ -d "$projdir/.git" ]]; then
            # Check for GitHub remote
            local remotes=$(cd "$projdir" && git remote -v 2>/dev/null | grep "origin.*github.com" | head -1)
            if [[ -n "$remotes" ]]; then
                project_type="cloned"
                # Extract repo info from remote
                if [[ "$remotes" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
                    remote_info="${match[1]}/${match[2]}"
                fi
                ((cloned_count++))
            else
                project_type="created"
                ((created_count++))
            fi
        else
            project_type="created"
            ((created_count++))
        fi
        
        # Apply filter if specified
        if [[ -n "$filter_type" && "$filter_type" != "$project_type" ]]; then
            continue
        fi
        
        ((project_count++))
        
        # Get last modified time
        local last_modified=""
        if command -v stat >/dev/null; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                last_modified=$(stat -f "%Sm" -t "%b %d" "$projdir" 2>/dev/null)
            else
                # Linux
                last_modified=$(stat -c "%y" "$projdir" 2>/dev/null | cut -d' ' -f1)
            fi
        fi
        
        # Display project info in ls -l style
        if [[ "$project_type" == "cloned" ]]; then
            printf "%-20s %s" "$projname" "$remote_info"
        else
            printf "%-20s %s" "$projname" "local"
        fi
        
        if [[ -n "$last_modified" ]]; then
            printf " %s" "$last_modified"
        fi
        
        echo ""
        
        # Show mise tools if requested
        if [[ "$show_tools" == true ]]; then
            local tools_output=$(cd "$projdir" && mise ls --current 2>/dev/null | grep -v "No tools" | head -3)
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
    local current_dir="$PWD"
    
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
        
        cd "$project_dir"
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
        cd "$project_dir"
    fi
    
    # Check if it's a git repository
    if [[ ! -d ".git" ]]; then
        echo "❌ Error: '$project_name' is not a git repository"
        echo "   This command only works with cloned projects"
        cd "$current_dir"
        return 1
    fi
    
    # Check if it has a remote
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$remote_url" ]]; then
        echo "❌ Error: '$project_name' has no remote origin"
        echo "   This appears to be a local git repository"
        cd "$current_dir"
        return 1
    fi
    
    echo "Updating project: $project_name"
    echo "Remote: $remote_url"
    echo ""
    
    # Get current branch
    local current_branch=$(git branch --show-current 2>/dev/null)
    if [[ -z "$current_branch" ]]; then
        echo "❌ Error: Unable to determine current branch"
        cd "$current_dir"
        return 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo "⚠️  Warning: You have uncommitted changes"
        echo ""
        git status --porcelain
        echo ""
        echo "Commit or stash your changes before updating"
        cd "$current_dir"
        return 1
    fi
    
    # Fetch latest changes
    echo "🔍 Checking for updates..."
    if ! git fetch origin "$current_branch" 2>/dev/null; then
        echo "❌ Error: Failed to fetch from remote"
        echo "   Check your network connection and remote access"
        cd "$current_dir"
        return 1
    fi
    
    # Check if there are updates available
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse "origin/$current_branch" 2>/dev/null)
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
        echo "✅ Already up to date"
        cd "$current_dir"
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
                cd "$current_dir"
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
        cd "$current_dir"
        return 1
    fi
    
    cd "$current_dir"
}

# Show detailed information about the current mise project
function showproject() {
  local mise_dir=$(get_mise_root)
  
  if [[ -z "$mise_dir" ]]; then
    echo "Not in a mise project"
    return 1
  fi

  local project_name="${mise_dir:t}"
  
  # Get last modified time
  local last_modified=""
  if command -v stat >/dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS
      last_modified=$(stat -f "%Sm" -t "%b %d %Y" "$mise_dir" 2>/dev/null)
    else
      # Linux
      last_modified=$(stat -c "%y" "$mise_dir" 2>/dev/null | cut -d' ' -f1)
    fi
  fi
  
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
  
  # Git information (if it's a git repo)
  if [[ -d ".git" ]]; then
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
    
  else
    echo "Git: not a repository"
  fi
  
  echo ""
  
  # Recent activity (last few git commits if available)
  if [[ -d ".git" ]]; then
    echo "Recent commits:"
    if git log --oneline -n 3 2>/dev/null | head -3; then
      git log --oneline -n 3 2>/dev/null | sed 's/^/  /'
    else
      echo "  (no commits yet)"
    fi
  fi
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
          local remote_url=$(cd "$projdir" && git remote get-url origin 2>/dev/null)
          if [[ -n "$remote_url" ]]; then
            cloned_projects+=("$projname")
          fi
        fi
      fi
    done
  fi
  
  _describe 'cloned projects' cloned_projects
}

# Register completion for updateproject
if [[ -n "$ZSH_VERSION" ]]; then
  # Only if zsh completion is initialized
  if whence compdef &>/dev/null; then
    compdef _updateproject_completion updateproject
  fi
fi

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
    
    # Check if it's a git repo with uncommitted changes
    local has_uncommitted=false
    if [[ -d "$project_path/.git" ]]; then
        cd "$project_path"
        local git_status=$(git status --porcelain 2>/dev/null)
        if [[ -n "$git_status" ]]; then
            has_uncommitted=true
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
                    echo "⚠️  Warning: $ahead unpushed commit(s)"
                fi
            fi
        fi
        cd - >/dev/null
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
    
    # If we're currently in the deleted/archived project, cd to home
    local current_dir="$PWD"
    if [[ "$current_dir" == "$project_path"* ]]; then
        echo "Moving out of deleted project directory..."
        cd "$MISE_PROJECTS_DIR"
    fi
}

# Setup zsh completion for rmproject (back to simple working pattern)
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

# Register completion for rmproject
if [[ -n "$ZSH_VERSION" ]]; then
  # Only if zsh completion is initialized
  if whence compdef &>/dev/null; then
    compdef _rmproject_completion rmproject
  fi
fi


# Create projects directory if it doesn't exist
[[ -d "$MISE_PROJECTS_DIR" ]] || mkdir -p "$MISE_PROJECTS_DIR"
