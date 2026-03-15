#!/usr/bin/env zsh
# project.sh — Project creation, cloning, updating, and removal
# Depends on: git_utils.sh, sandbox.sh

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
    echo "Usage: mkproject [--dry-run|-n] <project_name> [template_type]"
    echo "       Default template: base"
    echo ""
    echo "To add descriptions to your templates, add this line to your task files:"
    echo "  #MISE description=\"Your description here\""
}

# Escape replacement text for sed
function _mkproject_escape_sed() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//&/\\&}"
    echo "$value"
}

# Apply standard placeholders in generated docs
function _mkproject_apply_doc_placeholders() {
    local target_file="$1"
    local project_name="$2"

    [[ -f "$target_file" ]] || return 0

    local module_name="${project_name//-/_}"
    local project_name_sed=$(_mkproject_escape_sed "$project_name")
    local module_name_sed=$(_mkproject_escape_sed "$module_name")

    sed -i.bak \
        -e "s|<project-name>|${project_name_sed}|g" \
        -e "s|<project_name>|${project_name_sed}|g" \
        -e "s|<module_name>|${module_name_sed}|g" \
        "$target_file" && rm -f "$target_file.bak"
}

# Generate CLAUDE.md and AGENTS.md from shared header + template-specific content
function _mkproject_generate_docs() {
    local project_path="$1"
    local project_type="$2"
    local project_name="$3"

    local shared_dir="${_MISEWRAPPER_DOTFILES_DIR}/mise/.config/mise/tasks/mkproject/_shared"
    local template_dir="${_MISEWRAPPER_DOTFILES_DIR}/mise/.config/mise/tasks/mkproject/${project_type}"
    local base_dir="${_MISEWRAPPER_DOTFILES_DIR}/mise/.config/mise/tasks/mkproject/base"

    local claude_header="${shared_dir}/CLAUDE.header.md"
    local agents_header="${shared_dir}/AGENTS.header.md"
    local claude_body="${template_dir}/CLAUDE.project.md"
    local agents_body="${template_dir}/AGENTS.project.md"

    local legacy_claude="${template_dir}/CLAUDE.md"
    local legacy_agents="${template_dir}/AGENTS.md"
    local base_claude="${base_dir}/CLAUDE.project.md"
    local base_agents="${base_dir}/AGENTS.project.md"

    if [[ ! -f "$claude_header" ]]; then
        echo "⚠️  Warning: Missing shared header: $claude_header"
        return 1
    fi

    if [[ ! -f "$claude_body" ]]; then
        if [[ -f "$legacy_claude" ]]; then
            claude_body="$legacy_claude"
        elif [[ -f "$base_claude" ]]; then
            claude_body="$base_claude"
        else
            echo "⚠️  Warning: Missing CLAUDE project content for template '$project_type'"
            return 1
        fi
    fi

    if [[ ! -f "$agents_header" ]]; then
        agents_header="$claude_header"
    fi

    if [[ ! -f "$agents_body" ]]; then
        if [[ -f "$legacy_agents" ]]; then
            agents_body="$legacy_agents"
        elif [[ -f "$base_agents" ]]; then
            agents_body="$base_agents"
        else
            agents_body="$claude_body"
        fi
    fi

    cat "$claude_header" "$claude_body" > "$project_path/CLAUDE.md" || return 1
    cat "$agents_header" "$agents_body" > "$project_path/AGENTS.md" || return 1

    _mkproject_apply_doc_placeholders "$project_path/CLAUDE.md" "$project_name"
    _mkproject_apply_doc_placeholders "$project_path/AGENTS.md" "$project_name"

    return 0
}

# Handle cleanup for failed project creation
function _mkproject_handle_failure() {
    local project_path="$1"
    local project_name="$2"

    [[ -d "$project_path" ]] || return 0

    local archive_dir="${MISE_PROJECTS_DIR}/.archive"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local archive_path="${archive_dir}/${project_name}_failed_${timestamp}"

    local cleanup_action="${MKPROJECT_CLEANUP:-}"
    case "$cleanup_action" in
        keep|archive|delete)
            ;;
        *)
            cleanup_action=""
            ;;
    esac

    if [[ -z "$cleanup_action" && -t 0 ]]; then
        echo ""
        echo "How should I handle the incomplete project?"
        echo "  [1] Keep it in place"
        echo "  [2] Archive to: $archive_path"
        echo "  [3] Delete it"
        echo -n "Choice [1-3]: "
        read -r response
        case "$response" in
            2) cleanup_action="archive" ;;
            3) cleanup_action="delete" ;;
            *) cleanup_action="keep" ;;
        esac
    fi

    case "$cleanup_action" in
        archive)
            mkdir -p "$archive_dir"
            if mv "$project_path" "$archive_path"; then
                echo "📦 Archived incomplete project to:"
                echo "   $archive_path"
            else
                echo "❌ Error: Failed to archive incomplete project"
                return 1
            fi
            ;;
        delete)
            if rm -rf "$project_path"; then
                echo "🗑️  Deleted incomplete project: $project_path"
            else
                echo "❌ Error: Failed to delete incomplete project"
                return 1
            fi
            ;;
        *)
            # keep
            echo "⚠️  Incomplete project left at: $project_path"
            ;;
    esac

    return 0
}

# Create a new project
mkproject() {
    local project_name=""
    local project_type="base"
    local dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            -*)
                echo "❌ Error: Unknown option '$1'"
                echo "Usage: mkproject [--dry-run|-n] <project_name> [project_type]"
                return 1
                ;;
            *)
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                elif [[ "$project_type" == "base" ]]; then
                    project_type="$1"
                else
                    echo "❌ Error: Too many arguments"
                    echo "Usage: mkproject [--dry-run|-n] <project_name> [project_type]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$project_name" ]]; then
        echo "Usage: mkproject [--dry-run|-n] <project_name> [project_type]"
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

    if [[ "$dry_run" == true ]]; then
        local template_files_dir="${_MISEWRAPPER_DOTFILES_DIR}/mise/.config/mise/tasks/mkproject/${project_type}/files"

        echo "Dry run: mkproject"
        echo "  Project:  $project_name"
        echo "  Template: $project_type"
        echo "  Path:     $project_path"
        if [[ -d "$template_files_dir" ]]; then
            echo "  Files:    $template_files_dir"
        fi
        echo ""
        echo "Would:"
        echo "  - create $project_path"
        echo "  - create and trust .mise.toml"
        echo "  - run: mise run --cd \"$project_path\" \"mkproject:$project_type\""
        echo "  - generate CLAUDE.md and AGENTS.md"
        return 0
    fi

    echo "Creating $project_type project: $project_name"
    mkdir -p "$project_path"

    # Create basic .mise.toml in the project directory
    echo "" > "$project_path/.mise.toml"
    mise trust "$project_path/.mise.toml"

    # Run the project setup task in the project directory
    if mise run --cd "$project_path" "mkproject:$project_type"; then
        if ! _mkproject_generate_docs "$project_path" "$project_type" "$project_name"; then
            echo "⚠️  Warning: Failed to generate CLAUDE.md/AGENTS.md"
        fi
        echo "✅ Project '$project_name' created successfully"
        echo "📁 Location: $project_path"
        safe_cd "$project_path"
    else
        echo "❌ Error: Failed to create $project_type project"
        _mkproject_handle_failure "$project_path" "$project_name"
        echo "   You may want to investigate the issue before retrying"
        return 1
    fi
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
    local project_name=""
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
