#!/usr/bin/env zsh
# misewrapper.sh — Project management for mise-en-place
# https://mise.jdx.dev
#
# This is the entrypoint. It sources sub-modules in dependency order
# and initializes the projects directory.
#
# Module dependency graph:
#   git_utils.sh  (standalone)
#   sandbox.sh    (standalone, registers chpwd hooks)
#   project.sh    (depends on git_utils, sandbox)
#   navigate.sh   (depends on git_utils, sandbox; registers completions)

_MISEWRAPPER_DOTFILES_DIR="${0:a:h:h}"
source "$_MISEWRAPPER_DOTFILES_DIR/include/shared_vars.sh"

# Configuration
typeset -g MISE_PROJECTS_DIR=$PROJECT_DIR

# Load modules in dependency order
source "${0:a:h}/git_utils.sh"
source "${0:a:h}/sandbox.sh"
source "${0:a:h}/project.sh"
source "${0:a:h}/navigate.sh"

# Create projects directory if it doesn't exist
[[ -d "$MISE_PROJECTS_DIR" ]] || mkdir -p "$MISE_PROJECTS_DIR"
