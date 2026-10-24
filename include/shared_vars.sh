#!/usr/bin/env zsh

# Shared variables between .zshenv, misewrapper.sh, and tasks/bootstrap
HOME_DIR=${HOME_DIR:-$HOME} # Override to stow into a scratch dir: HOME_DIR=/tmp/x mise run bootstrap
PROJECT_DIR="$HOME_DIR/dev"

# Directories that are part of the dotfiles infrastructure, NOT stow packages.
# Everything else at the top level is auto-discovered as a stow package.
_DOTFILES_INFRA=("include" "lib" "docs" "tests" "tmp")
