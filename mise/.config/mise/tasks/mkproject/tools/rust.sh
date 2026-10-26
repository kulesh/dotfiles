#!/usr/bin/env zsh
#MISE description="Install Rust via mise"
#MISE dir="{{cwd}}"

echo "Installing Rust toolchain via mise..."
mise use rust@latest
mise install
# rustup's default profile has rustfmt and clippy but not the language server
mise exec -- rustup component add rust-analyzer
