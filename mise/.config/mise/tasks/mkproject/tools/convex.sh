#!/usr/bin/env zsh
#MISE description="Install Bun and Node for Convex development"
#MISE dir="{{cwd}}"

set -eo pipefail   # a failed step stops the template; mkproject reports it

echo "Installing Bun and Node..."
mise use bun@latest
mise use node@latest
mise install
