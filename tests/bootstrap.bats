#!/usr/bin/env bats
# Acceptance tests for .mise/tasks/bootstrap, run through the HOME_DIR
# seam so nothing touches the real $HOME.

load test_helper

setup() {
    command -v stow >/dev/null || skip "stow not installed"
    TARGET=$(mktemp -d)
    STUBS=$(mktemp -d)
    # Record machine-level calls instead of performing them.
    printf '#!/bin/sh\necho "mise $*"\n' > "$STUBS/mise"
    # gh reports "not logged in" so the login step is always exercised.
    printf '#!/bin/sh\n[ "$1 $2" = "auth status" ] && exit 1\necho "gh $*"\n' > "$STUBS/gh"
    chmod +x "$STUBS/mise" "$STUBS/gh"
}

teardown() {
    rm -rf "$TARGET" "$STUBS"
}

bootstrap() {
    local repo=${1:-$DOTFILES_ROOT}
    HOME_DIR="$TARGET" PATH="$STUBS:$PATH" run zsh "$repo/.mise/tasks/bootstrap"
}

@test "links every package into HOME_DIR" {
    bootstrap
    [ "$status" -eq 0 ]
    [ "$(readlink -f "$TARGET/.zshrc")" = "$(readlink -f "$DOTFILES_ROOT/zsh/.zshrc")" ]
    [ "$(readlink -f "$TARGET/.gitconfig")" = "$(readlink -f "$DOTFILES_ROOT/git/.gitconfig")" ]
    [ -f "$TARGET/.config/mise/config.toml" ]
}

@test "never links infrastructure directories" {
    bootstrap
    [ "$status" -eq 0 ]
    for f in shared_vars.sh misewrapper.sh architecture.md adrs bootstrap.bats; do
        [ ! -e "$TARGET/$f" ]
    done
}

@test "creates ~/dev as a real directory, not a link into the repo" {
    bootstrap
    [ "$status" -eq 0 ]
    [ -d "$TARGET/dev" ]
    [ ! -L "$TARGET/dev" ]
}

@test "works from a checkout outside ~/.dotfiles" {
    local elsewhere=$(mktemp -d)
    cp -a "$DOTFILES_ROOT/." "$elsewhere/"
    bootstrap "$elsewhere"
    [ "$status" -eq 0 ]
    [ "$(readlink -f "$TARGET/.zshrc")" = "$(readlink -f "$elsewhere/zsh/.zshrc")" ]
    rm -rf "$elsewhere"
}

@test "previews machine-level steps instead of running them" {
    bootstrap
    [ "$status" -eq 0 ]
    [[ "$output" == *"mise install --dry-run"* ]]
    [[ "$output" == *"would run: mise trust"* ]]
    [[ "$output" != *$'\nmise trust'* ]]
}

@test "previews GitHub login over SSH when not authenticated" {
    bootstrap
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: gh auth login --hostname github.com --git-protocol ssh"* ]]
    [[ "$output" != *$'\ngh auth login'* ]]
}

@test "is safe to run twice" {
    bootstrap
    [ "$status" -eq 0 ]
    bootstrap
    [ "$status" -eq 0 ]
}

@test "stops at the first failure instead of continuing" {
    printf '#!/bin/sh\nexit 1\n' > "$STUBS/stow"
    chmod +x "$STUBS/stow"
    bootstrap
    [ "$status" -ne 0 ]
    [[ "$output" != *"mise install"* ]]
}

@test "previews cloning own repos, skipping dotfiles and existing projects" {
    cat > "$STUBS/gh" <<'STUB'
#!/bin/sh
case "$1 $2" in
  "auth status") exit 0;;
  "repo list") printf 'kulesh/dotfiles\nkulesh/alpha\nkulesh/beta\n';;
esac
STUB
    mkdir -p "$TARGET/dev/beta"
    bootstrap
    [ "$status" -eq 0 ]
    [[ "$output" == *"would clone kulesh/alpha"* ]]
    [[ "$output" != *"would clone kulesh/beta"* ]]
    [[ "$output" != *"would clone kulesh/dotfiles"* ]]
}
