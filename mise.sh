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

# As .zshenv sets it, so Homebrew here reads the same tap trust
# (~/.config/homebrew/trust.json, linked by bootstrap) as your shells.
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

# 1. Xcode Command Line Tools provide git and a compiler. The installer
#    is a GUI dialog that returns immediately, so wait until it's done.
if ! xcode-select -p &>/dev/null; then
    # Fails if an install it started is still pending: wait for that one.
    xcode-select --install || true
    echo "Complete the Xcode Command Line Tools dialog. Waiting..."
    until xcode-select -p &>/dev/null; do sleep 5; done
fi

# 2. Homebrew. mise drives it but can't install it. Check by path, not
#    PATH: a fresh shell won't have brew on PATH even after it's installed.
if [[ $(uname -m) == arm64 ]]; then prefix=/opt/homebrew; else prefix=/usr/local; fi
brew=${HOMEBREW_PREFIX:-$prefix}/bin/brew
[[ -x $brew ]] || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$("$brew" shellenv)"

# 3. mise, via Homebrew so `mup` upgrades it along with everything else.
#    .mise.toml sets min_version, and an older mise misreads the config, so a
#    Homebrew mise that's already here is upgraded. One installed another way
#    keeps its own updater; min_version says if it's too old.
relink="If Homebrew says the link step failed, run: $brew link --overwrite mise
Then run mise.sh again."
if "$brew" list --formula mise &>/dev/null; then
    "$brew" upgrade mise || { echo "mise.sh: Homebrew couldn't upgrade mise. $relink" >&2; exit 1; }
elif ! command -v mise &>/dev/null; then
    "$brew" install mise
fi
# An upgrade can leave mise unlinked: the old version is gone and the new
# one isn't on PATH. Stop here rather than partway through bootstrap.
hash -r
mise --version &>/dev/null || { echo "mise.sh: mise doesn't run. $relink" >&2; exit 1; }

# 4. The repo lives at ~/.dotfiles, where .zshenv and dsync expect it.
[[ -d $dotfiles ]] || git clone "$repo" "$dotfiles"

# 5. Hand off: mise reads .mise.toml and runs .mise/tasks/bootstrap.
cd "$dotfiles"
mise trust
mise bootstrap
