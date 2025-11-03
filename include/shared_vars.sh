#!/usr/bin/env zsh

# Shared variables between install.sh and revert.sh
HOME_DIR=$HOME # Makes it easy to test
PROJECT_DIR="$HOME_DIR/dev"
STOWED_PACKAGES=("zsh" "git" "ghostty" "ssh" "mise" "nvim" "brew" "starship" "dev" "claude")
