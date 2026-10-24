#!/usr/bin/env bash
# mise.sh — Bootloader for dotfiles
#
# Installs Xcode CLI tools, Homebrew, and mise, then hands off to
# mise bootstrap which reads .mise.toml from the repo root.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/kulesh/dotfiles/main/mise.sh)
set -e

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
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
eval "$(~/.local/bin/mise activate bash)"

# --- Bootstrap from repo ---
echo "Running mise bootstrap..."
mise bootstrap --from https://github.com/kulesh/dotfiles.git --yes
