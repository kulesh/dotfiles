#!/usr/bin/env zsh
#MISE description="Setup Rails project"
#MISE dir="{{cwd}}"
#MISE depends=["mkproject:base", "mkproject:tools:ruby"]

echo "Setting up Rails project..."

# Use mise exec to ensure correct Ruby environment
mise exec -- gem install rails --no-document
mise exec -- rails new . --skip-git
mise exec -- bundle install

echo "Rails project setup complete!"
