#!/usr/bin/env zsh
#MISE description="Setup Rails project"
#MISE dir="{{cwd}}"
#MISE depends=["mkproject:base", "mkproject:tools:ruby"]

echo "Setting up Rails project..."

# Copy Rails-specific static files (will override base files if same name)
TEMPLATE_DIR="${0:a:h}/rails"
if [[ -d "$TEMPLATE_DIR" ]]; then
    echo "Copying Rails template files..."
    cp -r "$TEMPLATE_DIR"/. "$PWD/"
fi

# Use mise exec to ensure correct Ruby environment
mise exec -- gem install rails --no-document
mise exec -- rails new . --skip-git
mise exec -- bundle install

echo "Rails project setup complete!"
