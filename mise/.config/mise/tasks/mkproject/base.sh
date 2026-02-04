#!/usr/bin/env zsh
#MISE description="Initialize basic project structure"
#MISE dir="{{cwd}}"

source "${0:a:h}/_shared/template_helpers.sh"

echo "Initializing project in: $PWD"

# Copy static files from template directory
copy_template_files "base" "base"

git init
touch README.md .gitignore
bd init
bd doctor --fix --yes

# Use the directory name as project name
echo "# $(basename "$PWD")" > README.md

echo "Basic project structure created"
