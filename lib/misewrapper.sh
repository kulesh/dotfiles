#!/usr/bin/env zsh
# misewrapper.zsh
# A wrapper script for mise-en-place (https://mise.jdx.dev)
# Providing convenient project management functions

source include/shared_vars.sh
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

# Create a new mise project
function mkproject() {
  if [[ $# -lt 1 ]]; then
    echo "Project name is required: mkproject <project_name>"
    return 1
  fi

  local projname="$1"

  # Create the project directory if it doesn't exist
  local projdir="${MISE_PROJECTS_DIR}/${projname}"
  if [[ ! -d "$projdir" ]]; then
    echo "Creating project directory $projdir"
    mkdir -p "$projdir"
  fi

  # Change to the project directory
  cd "$projdir"

  # Create a .mise.toml file to mark this as a mise project
  if [[ ! -e ".mise.toml" ]]; then
    echo "Creating .mise.toml in $projdir"
    touch .mise.toml
    
    # Trust the newly created config file
    echo "Trusting the mise configuration file"
    mise trust
  fi

  echo "Project $projname created and mise initialized"
}

# List all mise projects
function lsprojects() {
  if [[ ! -d "$MISE_PROJECTS_DIR" ]]; then
    echo "No projects directory found at $MISE_PROJECTS_DIR"
    return 1
  fi

  echo "Available projects:"
  for projdir in "$MISE_PROJECTS_DIR"/*(N/); do
    local projname=${projdir:t}
    if [[ -e "$projdir/.mise.toml" || -e "$projdir/.tool-versions" ]]; then
      echo "  $projname"
    fi
  done
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
