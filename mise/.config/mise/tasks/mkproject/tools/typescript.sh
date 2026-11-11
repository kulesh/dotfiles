#!/usr/bin/env zsh
#MISE description="Install Bun via mise"
#MISE dir="{{cwd}}"

set -eo pipefail   # a failed step stops the template; mkproject reports it

echo "Installing Bun runtime via mise..."
mise use bun@latest
mise install
