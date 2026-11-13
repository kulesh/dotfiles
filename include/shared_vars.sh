#!/usr/bin/env zsh

# Shared between .zshenv and the bootstrap task
# Where projects live, as ~/dev/<org>/<repo>. Exported, so the project
# commands (mise tasks, each its own process) read the same place.
export PROJECT_DIR="$HOME/dev"
