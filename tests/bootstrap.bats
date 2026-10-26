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

@test "creates ~/.ssh as a private real directory so keys stay out of the repo" {
    bootstrap
    [ "$status" -eq 0 ]
    [ -d "$TARGET/.ssh" ]
    [ ! -L "$TARGET/.ssh" ]
    [ "$(stat -c %a "$TARGET/.ssh" 2>/dev/null || stat -f %Lp "$TARGET/.ssh")" = "700" ]
    [ -L "$TARGET/.ssh/config" ]
}

@test "previews generating and uploading a key when logged in without one" {
    printf '#!/bin/sh\n[ "$1 $2" = "auth status" ] && exit 0\n' > "$STUBS/gh"
    bootstrap
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: ssh-keygen -t ed25519 -f $TARGET/.ssh/id_ed25519"* ]]
    [[ "$output" == *"would run: gh ssh-key add $TARGET/.ssh/id_ed25519.pub"* ]]
}

@test "an existing file at a target stops the run and changes nothing" {
    local repo=$(mktemp -d)
    cp -a "$DOTFILES_ROOT/." "$repo/"
    local before=$(git -C "$repo" status --porcelain)
    echo "local" > "$TARGET/.gitconfig"
    bootstrap "$repo"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Stopped: a file above already exists"* ]]
    [ "$(cat "$TARGET/.gitconfig")" = "local" ]
    [ "$(git -C "$repo" status --porcelain)" = "$before" ]
    rm -rf "$repo"
}

@test "ssh config has no hardcoded home directory" {
    ! grep -q '/Users/' "$DOTFILES_ROOT/ssh/.ssh/config"
}

signing_gh_stub() {   # logged in; $1 = keys already registered for signing
    cat > "$STUBS/gh" <<STUB
#!/bin/sh
case "\$1 \$2" in
  "auth status") exit 0;;
  "api user/ssh_signing_keys") printf '%s\n' "$1";;
esac
STUB
    chmod +x "$STUBS/gh"
}

@test "previews registering the key for signing when GitHub doesn't have it" {
    command -v ssh-keygen >/dev/null || skip "ssh-keygen not installed"
    mkdir -p -m 700 "$TARGET/.ssh"
    ssh-keygen -q -t ed25519 -N '' -f "$TARGET/.ssh/id_ed25519" -C test
    signing_gh_stub "ssh-ed25519 AAAAsomeothermachine"
    bootstrap
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: gh ssh-key add $TARGET/.ssh/id_ed25519.pub --type signing"* ]]
    [[ "$output" == *"would write $TARGET/.config/git/allowed_signers"* ]]
}

@test "skips registering a signing key GitHub already has" {
    command -v ssh-keygen >/dev/null || skip "ssh-keygen not installed"
    mkdir -p -m 700 "$TARGET/.ssh"
    ssh-keygen -q -t ed25519 -N '' -f "$TARGET/.ssh/id_ed25519" -C test
    signing_gh_stub "$(cut -d' ' -f1,2 "$TARGET/.ssh/id_ed25519.pub")"
    bootstrap
    [ "$status" -eq 0 ]
    [[ "$output" != *"--type signing"* ]]
}

@test "the stowed git config signs commits that verify against allowed_signers" {
    command -v ssh-keygen >/dev/null || skip "ssh-keygen not installed"
    mkdir -p -m 700 "$TARGET/.ssh" "$TARGET/.config/git"
    ssh-keygen -q -t ed25519 -N '' -f "$TARGET/.ssh/id_ed25519" -C test
    local email=$(git config -f "$DOTFILES_ROOT/git/.gitconfig" user.email)
    echo "$email namespaces=\"git\" $(cut -d' ' -f1,2 "$TARGET/.ssh/id_ed25519.pub")" > "$TARGET/.config/git/allowed_signers"
    local repo=$(mktemp -d)
    git -C "$repo" init -q
    HOME="$TARGET" GIT_CONFIG_GLOBAL="$DOTFILES_ROOT/git/.gitconfig" git -C "$repo" commit -q --allow-empty -m signed </dev/null
    run env HOME="$TARGET" GIT_CONFIG_GLOBAL="$DOTFILES_ROOT/git/.gitconfig" git -C "$repo" verify-commit HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"Good \"git\" signature for $email"* ]]
    rm -rf "$repo"
}
