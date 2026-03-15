#!/usr/bin/env zsh

# Shared variables between install.sh, .zshenv, and misewrapper.sh
HOME_DIR=$HOME # Makes it easy to test
PROJECT_DIR="$HOME_DIR/dev"

# Directories that are part of the dotfiles infrastructure, NOT stow packages.
# Everything else at the top level is auto-discovered as a stow package.
_DOTFILES_INFRA=("include" "lib" "docs" "tests" "tmp")
