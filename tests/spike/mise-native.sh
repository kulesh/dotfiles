#!/usr/bin/env bash
# Phase 0 of docs/mise-native.md: check, on a real Mac, what the clean-sheet
# design assumes. Changes nothing outside one scratch directory:
#   - downloads a current mise into it (your installed mise is untouched)
#   - applies dotfiles only into scratch homes, from fresh clones of GitHub's main
#   - runs packages and macOS defaults as previews (--dry-run)
# Usage: bash tests/spike/mise-native.sh [repo]   (default: GitHub main, not your checkout)
# Then send back the report it names at the end.
set -uo pipefail

dotfiles=${1:-https://github.com/kulesh/dotfiles.git}
tmp=${TMPDIR:-/tmp}
spike=$(mktemp -d "${tmp%/}/mise-spike.XXXXXX")
real_home=$HOME
exec > >(tee "$spike/report.txt") 2>&1

section() { printf '\n=== %s\n' "$*"; }
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1" 2>/dev/null; }   # GNU, then BSD
infra() { case $1 in include|lib|docs|tests|tmp) return 0;; esac; return 1; }

# Point mise and HOME at a fresh scratch home ($1), with its own state.
use_home() {
    export HOME=$spike/$1 MISE_YES=1 MISE_VERSION_CHECK=0
    export MISE_CONFIG_DIR=$HOME/.config/mise MISE_STATE_DIR=$spike/$1.state
    export MISE_DATA_DIR=$spike/data MISE_CACHE_DIR=$spike/cache
    export MISE_TRUSTED_CONFIG_PATHS=$spike
    export XDG_CONFIG_HOME=$HOME/.config XDG_STATE_HOME=$MISE_STATE_DIR XDG_DATA_HOME=$spike/data XDG_CACHE_HOME=$spike/cache
    mkdir -p "$HOME"
    git clone -q "$dotfiles" "$HOME/.dotfiles"
    cd "$HOME/.dotfiles" || exit 1
}

# The clean-sheet linking config from docs/mise-native.md, plus Pi settings
# trimmed to the keys we own.
write_clean_sheet_config() {
    local groups=""
    for d in */; do d=${d%/}; infra "$d" || groups="$groups\"$d\", "; done
    cat >> .mise.toml <<EOF

[bootstrap]
dotfile_groups = [${groups%, }]

[dotfiles]
"~/.ssh" = { permissions = "0700" }

[dotfile_groups.ssh]
root = "ssh"
[dotfile_groups.ssh.entries]
"~/.ssh/config" = { mode = "copy", permissions = "0600" }

[dotfile_groups.nvim]
root = "nvim"
[dotfile_groups.nvim.entries]
"~/.config/nvim" = { mode = "symlink" }

[dotfile_groups.pi]
root = "pi"
[dotfile_groups.pi.entries]
"~/.pi/agents/settings.json/ours" = { merge = true }
EOF
    /usr/bin/python3 -I - pi/.pi/agents/settings.json <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d.pop("lastChangelogVersion", None)
json.dump(d, open(p, "w"), indent=2)
EOF
    git -c user.name=spike -c user.email=spike@localhost -c commit.gpgsign=false commit -qam "clean-sheet config (spike)"
}

show_home() {
    for p in .zshrc dev .ssh .ssh/config .local/bin .local/bin/secret .claude .claude/settings.json .pi .pi/agents/settings.json .config/nvim .gitconfig; do
        if [[ -L $HOME/$p ]]; then kind="link -> $(readlink "$HOME/$p" | sed "s|$spike/||")"
        elif [[ -d $HOME/$p ]]; then kind="dir"
        elif [[ -f $HOME/$p ]]; then kind="file"
        else kind="MISSING"; fi
        printf '  %-26s %-4s %s\n' "$p" "$(mode "$HOME/$p")" "$kind"
    done
    echo "  repo changes made by apply (expect none):"
    git -C "$HOME/.dotfiles" status --short | sed 's/^/    /'
}

section "Machine"
sw_vers 2>/dev/null || uname -a
echo "arch: $(uname -m)"
installed=$(PATH=/opt/homebrew/bin:$real_home/.local/bin:$PATH command -v mise)
echo "installed mise: ${installed:-none} $($installed --version 2>/dev/null)"
echo "brew: $(command -v brew || echo 'not on PATH')"

section "Scratch mise"
mkdir -p "$spike/bin"
if [[ -n ${SPIKE_MISE:-} ]]; then
    cp "$SPIKE_MISE" "$spike/bin/mise"
else
    curl -fsSL https://mise.run | MISE_INSTALL_PATH=$spike/bin/mise MISE_QUIET=1 sh >/dev/null
fi
mise() { "$spike/bin/mise" "$@"; }
mise --version

section "1. brew: installs bottles itself (preview, brew hidden from PATH)"
use_home pkgs
mkdir -p "$spike/pkgs-config"
cat > "$spike/pkgs-config/mise.toml" <<'EOF'
[bootstrap.packages]
"brew:sl" = "latest"
"brew-cask:font-hack-nerd-font" = "latest"
EOF
PATH=$spike/bin:/usr/bin:/bin:/usr/sbin:/sbin mise -C "$spike/pkgs-config" bootstrap packages apply --dry-run
echo "exit: $?  ('brew install' = shells out to Homebrew; bottle/download lines = mise does it itself)"

section "2. Fresh Mac: clean-sheet linking from an empty home"
use_home fresh
write_clean_sheet_config
mkdir -p "$HOME/.pi/agents"   # Pi already ran here and wrote its own state
printf '{\n  "lastChangelogVersion": "0.99.0",\n  "defaultModel": "changed-in-pi"\n}\n' > "$HOME/.pi/agents/settings.json"
mise dot apply; echo "apply exit: $?"
mise dot apply | tail -1; echo "second apply exit: $? (expect no changes)"
show_home
echo "  merged Pi settings (expect lastChangelogVersion kept, defaultModel back to ours):"
sed 's/^/    /' "$HOME/.pi/agents/settings.json"
mise dot status --missing >/dev/null; echo "  dot status --missing exit: $? (0 = no drift)"

section "3. Existing Mac: from Stow's links to the clean-sheet config"
stow_all() { for d in */; do d=${d%/}; infra "$d" || stow --dir="$HOME/.dotfiles" --target="$HOME" "$@" "$d" 2>/dev/null; done; }
if command -v stow >/dev/null; then
    echo "--- 3a. apply straight over Stow's links (mise's docs say no unstow is needed)"
    use_home migrate-direct
    stow_all
    echo "Stow folded these into the repo: $(cd "$HOME" && for d in dev .ssh .claude .pi .config/nvim .local/bin; do [[ -L $d ]] && printf '%s ' "$d"; done)"
    write_clean_sheet_config
    mise dot apply; echo "apply exit: $?"
    show_home
    echo "--- 3b. unstow first (stow -D), then apply"
    use_home migrate-unstow
    stow_all
    write_clean_sheet_config
    stow_all -D
    mise dot apply; echo "apply exit: $?"
    show_home
else
    echo "stow not installed; skipped"
fi

section "4. macOS defaults: is ~ expanded? (preview)"
mkdir -p "$spike/defaults-config"
cat > "$spike/defaults-config/mise.toml" <<'EOF'
[bootstrap.directories."~/Pictures/Screenshots"]

[bootstrap.macos.defaults]
"com.apple.screencapture" = { location = "~/Pictures/Screenshots" }
EOF
mise -C "$spike/defaults-config" bootstrap --only files,macos-defaults --dry-run

section "5. Bootstrap plan with the clean-sheet config (read-only; packages are machine-wide)"
use_home plan
write_clean_sheet_config
mise bootstrap plan 2>&1 | tail -30

section "Done"
echo "Report:  $spike/report.txt"
echo "Cleanup: rm -rf $spike"
