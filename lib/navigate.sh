#!/usr/bin/env zsh
# navigate.sh — Project navigation, display, and discovery
# Depends on: git_utils.sh, sandbox.sh

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

# =============================================================================
# Zsh completions
# =============================================================================

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
    if whence compdef &>/dev/null; then
        compdef _mise_project_completion workon
        compdef _updateproject_completion updateproject
        compdef _rmproject_completion rmproject
    fi
fi
