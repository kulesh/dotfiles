#!/usr/bin/env zsh
#MISE description="Setup Rails project"
#MISE dir="{{cwd}}"
#MISE depends=["mkproject:base", "mkproject:tools:ruby"]

set -eo pipefail   # a failed step stops the template; mkproject reports it

source "${0:a:h}/_shared/template_helpers.sh"

echo "Setting up Rails project..."

# Copy Rails-specific static files (will override base files if same name)
copy_template_files "rails" "Rails"

# Use mise exec to ensure correct Ruby environment
mise exec -- gem install rails --no-document
mise exec -- rails new . --skip-git --force   # over base's README.md and .gitignore, without asking
mise exec -- bundle install

echo "Rails project setup complete!"
