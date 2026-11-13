#!/usr/bin/env bats
# Acceptance tests for the Seatbelt profile behind workon -s
# (sandbox/.config/sandbox/profiles/default.sb), run with sandbox-exec
# against a scratch home and project. macOS only.
#
# The profile is a deny-list (ADR-002): it can't stop every write, so it
# stops the ones that matter most, the files your Mac later runs outside the
# sandbox. Everyday work inside the project and tool state stays writable.

load test_helper

setup() {
    command -v sandbox-exec >/dev/null || skip "sandbox-exec is macOS only"
    # Real paths: Seatbelt matches resolved paths, and /var is /private/var.
    export HOME=$(cd "$(scratch)" && pwd -P)
    PROJECT=$HOME/dev/acme/app
    mkdir -p "$PROJECT" "$HOME/.ssh" "$HOME/.dotfiles/claude/.claude" "$HOME/.dotfiles/lib"
    git -C "$PROJECT" init -q
    git -C "$PROJECT" config user.email test@example.com
    git -C "$PROJECT" config user.name Test
}

sandboxed() {   # sandboxed <command...>: run it under the profile
    run sandbox-exec -f "$DOTFILES_ROOT/sandbox/.config/sandbox/profiles/default.sb" \
        -D "HOME=$HOME" -D "PROJECT=$PROJECT" -D "SSH_REAL=$HOME/.ssh" "$@"
}

can_write() {   # can_write <file>: the sandbox may create it
    mkdir -p "$(dirname "$1")"
    sandboxed /bin/sh -c 'echo x > "$1"' _ "$1"
    [ "$status" -eq 0 ]
}

cannot_write() {   # cannot_write <file>: the sandbox may not create it
    mkdir -p "$(dirname "$1")"
    sandboxed /bin/sh -c 'echo x > "$1"' _ "$1"
    [ "$status" -ne 0 ]
    [ ! -e "$1" ]
}

@test "work inside the project, including commits, is allowed" {
    can_write "$PROJECT/src/main.py"
    sandboxed /bin/sh -c 'cd "$1" && git add -A && git commit -q -m work' _ "$PROJECT"
    [ "$status" -eq 0 ]
}

@test "tool state and agent settings stay writable" {
    can_write "$HOME/.cache/tool/state"
    can_write "$HOME/.config/some-tool/state.json"
    can_write "$HOME/.local/share/some-tool/data"
    can_write "$HOME/.dotfiles/claude/.claude/settings.json"
}

@test "git can't be made to run code outside the sandbox: hooks and config are read-only" {
    cannot_write "$PROJECT/.git/hooks/post-checkout"
    sandboxed git -C "$PROJECT" config core.fsmonitor "touch $HOME/owned"
    [ "$status" -ne 0 ]
    ! grep -q fsmonitor "$PROJECT/.git/config"
}

@test "the dotfiles checkout is read-only, apart from the agents' linked settings" {
    cannot_write "$HOME/.dotfiles/lib/reload.zsh"
    cannot_write "$HOME/.dotfiles/sandbox/.config/sandbox/profiles/default.sb"
    cannot_write "$HOME/.dotfiles/.mise.toml"
    cannot_write "$HOME/.dotfiles/.git/hooks/post-merge"
    cannot_write "$HOME/.dotfiles/claude/.claude/statusline.sh"
    cannot_write "$HOME/.dotfiles/claude/.claude/skills/evil/SKILL.md"
}

@test "shell startup files and login items are read-only" {
    for file in .zshrc .zshenv .zprofile .zlogin .zlogout .bashrc .bash_profile .profile; do
        cannot_write "$HOME/$file"
    done
    cannot_write "$HOME/Library/LaunchAgents/evil.plist"
}

@test "configs and commands that tools run on the host are read-only" {
    for dir in mise git gh starship ghostty homebrew nvim yazi sandbox; do
        cannot_write "$HOME/.config/$dir/evil"
    done
    cannot_write "$HOME/.local/bin/claude"
}

@test "other repos, org config and the shared ~/dev config are read-only" {
    mkdir -p "$HOME/dev/acme/other/.git"
    cannot_write "$HOME/dev/acme/other/src/main.py"
    cannot_write "$HOME/dev/acme/other/.git/hooks/post-checkout"
    cannot_write "$HOME/dev/acme/mise.toml"
    cannot_write "$HOME/dev/.mise.toml"
}

@test "the project's own mise config and its .git can't be swapped" {
    for file in .mise.toml mise.toml .mise.local.toml mise.local.toml .tool-versions .config/mise.toml .mise/config.toml mise/config.toml; do
        cannot_write "$PROJECT/$file"
    done
    sandboxed mv "$PROJECT/.git" "$HOME/elsewhere-git"
    [ "$status" -ne 0 ]
    [ -d "$PROJECT/.git" ]
}

@test "zsh's completion dump and colima's ssh config are read-only" {
    cannot_write "$HOME/.zcompdump"
    cannot_write "$HOME/.config/colima/ssh_config"
}

@test "of the agents' linked settings, only the settings files themselves are writable" {
    can_write "$HOME/.dotfiles/pi/.pi/agents/settings.json"
    cannot_write "$HOME/.dotfiles/claude/.local/bin/git"
    cannot_write "$HOME/.dotfiles/pi/.pi/agents/other.json"
}
