#!/usr/bin/env zsh
#MISE description="Initialize basic project structure"
#MISE dir="{{cwd}}"

echo "Initializing project in: $PWD"

# Copy static files from template directory
TEMPLATE_DIR="${0:a:h}/base"
if [[ -d "$TEMPLATE_DIR" ]]; then
    echo "Copying base template files..."
    cp -r "$TEMPLATE_DIR"/. "$PWD/"
fi

git init
touch README.md .gitignore
bd init
bd doctor --fix --yes

# Use the directory name as project name
echo "# $(basename "$PWD")" > README.md

echo "Basic project structure created"
