#!/usr/bin/env zsh

# Shared variables between install.sh and revert.sh
HOME_DIR=$HOME # Makes it easy to test
BACKUP_ROOT="$HOME_DIR/.dotbackup"
STOWED_PACKAGES=("zsh" "git" "mise" "nvim" "brew" "starship" "dev")
PROJECT_DIR="$HOME_DIR/dev"
