#!/usr/bin/env zsh
#MISE description="Install Bun via mise"
#MISE dir="{{cwd}}"

echo "Installing Bun runtime via mise..."
mise use bun@latest
mise install
