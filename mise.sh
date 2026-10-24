#!/usr/bin/env bash
# mise.sh — Bootloader for dotfiles
#
# Installs prerequisites, clones this repo, then hands off to mise bootstrap.
# This is the only script you run on a fresh machine:
#
#   curl -fsSL https://raw.githubusercontent.com/kulesh/dotfiles/main/mise.sh | bash
#
# Or if already cloned:
#
#   ~/.dotfiles/mise.sh
set -e

DOTFILES_REPO="https://github.com/kulesh/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

# --- Xcode CLI tools (provides git, clang on macOS) ---
if [[ "$(uname)" == "Darwin" ]] && ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Waiting for Xcode CLI tools to install (this takes a few minutes)..."
    until xcode-select -p &>/dev/null; do
        sleep 5
    done
    echo "Xcode CLI tools installed."
fi

# --- Homebrew (mise skips brew: packages if brew is missing) ---
if [[ "$(uname)" == "Darwin" ]] && ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    if [[ $(uname -m) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# --- mise ---
if ! command -v mise &>/dev/null; then
    echo "Installing mise..."
    curl -fsSL https://mise.run | sh
fi

# Make mise available in this session
eval "$(~/.local/bin/mise activate bash)"

# --- Dotfiles repo ---
if [[ ! -d "$DOTFILES_DIR" ]]; then
    echo "Cloning dotfiles..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# --- Hand off to mise ---
cd "$DOTFILES_DIR"
mise trust
echo "Running mise bootstrap..."
mise bootstrap
