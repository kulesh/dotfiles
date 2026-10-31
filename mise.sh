#!/usr/bin/env bash
# mise.sh — install what mise can't install itself, then hand off to it.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/kulesh/dotfiles/main/mise.sh)
#
# Safe to re-run: every step checks before acting.
set -euo pipefail

repo=https://github.com/kulesh/dotfiles.git
dotfiles=$HOME/.dotfiles

[[ $(uname) == Darwin ]] || { echo "mise.sh: macOS only" >&2; exit 1; }

# 1. Xcode Command Line Tools provide git and a compiler. The installer
#    is a GUI dialog that returns immediately, so wait until it's done.
if ! xcode-select -p &>/dev/null; then
    xcode-select --install
    echo "Complete the Xcode Command Line Tools dialog. Waiting..."
    until xcode-select -p &>/dev/null; do sleep 5; done
fi

# 2. Homebrew. mise drives it but can't install it. Check by path, not
#    PATH: a fresh shell won't have brew on PATH even after it's installed.
if [[ $(uname -m) == arm64 ]]; then brew=/opt/homebrew/bin/brew; else brew=/usr/local/bin/brew; fi
[[ -x $brew ]] || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$("$brew" shellenv)"

# 3. mise, via Homebrew so `mup` upgrades it along with everything else.
command -v mise &>/dev/null || "$brew" install mise

# 4. The repo lives at ~/.dotfiles, where .zshenv and dsync expect it.
[[ -d $dotfiles ]] || git clone "$repo" "$dotfiles"

# 5. Hand off: mise reads .mise.toml and runs .mise/tasks/bootstrap.
cd "$dotfiles"
mise trust
mise bootstrap
