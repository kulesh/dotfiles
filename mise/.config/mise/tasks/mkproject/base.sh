#!/usr/bin/env zsh
#MISE description="Initialize basic project structure"
#MISE dir="{{cwd}}"

echo "Initializing project in: $PWD"

git init
touch README.md .gitignore

# Use the directory name as project name
echo "# $(basename "$PWD")" > README.md

echo "Basic project structure created"
