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

# 3. The repo lives at ~/.dotfiles, where .zshenv and dsync expect it. It
#    comes before mise: its .mise.toml says how new a mise it needs.
[[ -d $dotfiles ]] || git clone "$repo" "$dotfiles"

# 4. mise, via Homebrew so `mup` upgrades it along with everything else. An
#    older mise than the config's min_version misreads it, so a Homebrew mise
#    below that (or one that doesn't run) is upgraded; one that meets it is
#    left alone, since keeping it current is mup's job and brew upgrade can
#    hang. A mise installed another way keeps its own updater.
version_ge() {   # version_ge A B: dotted version A is at least B
    local IFS=. i a b
    read -ra a <<< "$1"; read -ra b <<< "$2"
    for ((i = 0; i < ${#b[@]}; i++)); do
        (( 10#${a[i]:-0} > 10#${b[i]} )) && return 0
        (( 10#${a[i]:-0} < 10#${b[i]} )) && return 1
    done
    return 0
}
floor=$(awk -F'"' '/^min_version/ { for (i = 2; i <= NF; i += 2) v = $i; print v }' "$dotfiles/.mise.toml" 2>/dev/null || true)
current=$(mise --version 2>/dev/null | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
relink="If Homebrew says the link step failed, run: $brew link --overwrite mise
Then run mise.sh again."
if "$brew" list --formula mise &>/dev/null; then
    if [[ -z $current ]] || { [[ -n $floor ]] && ! version_ge "$current" "$floor"; }; then
        "$brew" upgrade mise || { echo "mise.sh: Homebrew couldn't upgrade mise. $relink" >&2; exit 1; }
    fi
elif ! command -v mise &>/dev/null; then
    "$brew" install mise
fi
# An upgrade can leave mise unlinked: the old version is gone and the new
# one isn't on PATH. Stop here rather than partway through bootstrap.
hash -r
mise --version &>/dev/null || { echo "mise.sh: mise doesn't run. $relink" >&2; exit 1; }

# 5. Hand off: mise reads .mise.toml and runs .mise/tasks/bootstrap.
cd "$dotfiles"
mise trust
mise bootstrap
