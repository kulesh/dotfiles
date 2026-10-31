#!/usr/bin/env bats
# Acceptance tests for linking (mise dotfile groups, .mise.toml) and the
# bootstrap task, run through the preview task: a scratch HOME, isolated
# mise state, and machine-level steps printed instead of run.

load test_helper

setup() {
    command -v mise >/dev/null || skip "mise not installed"
    export MISE_OFFLINE=1 MISE_VERSION_CHECK=0
    TARGET=$(mktemp -d)
    STUBS=$(mktemp -d)
    # gh reports "not logged in" so the login step is always exercised.
    printf '#!/bin/sh\n[ "$1 $2" = "auth status" ] && exit 1\necho "gh $*"\n' > "$STUBS/gh"
    chmod +x "$STUBS/gh"
}

teardown() {
    rm -rf "$TARGET" "$STUBS"
}

preview() {
    local repo=${1:-$DOTFILES_ROOT}
    PATH="$STUBS:$PATH" run zsh "$repo/.mise/tasks/preview" "$TARGET"
}

repo_copy() {
    local repo=$(mktemp -d)
    cp -a "$DOTFILES_ROOT/." "$repo/"
    echo "$repo"
}

stowed_by_stow() {   # $1 = repo; linked the way the Stow-based bootstrap did it
    command -v stow >/dev/null || skip "stow not installed"
    mkdir -p "$TARGET/dev" "$TARGET/.local/bin"
    mkdir -p -m 700 "$TARGET/.ssh"
    local package
    for package in bin claude dev ghostty git mise nvim pi sandbox ssh starship yazi zsh; do
        stow --dir="$1" --target="$TARGET" "$package"
    done
}

mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

@test "links every package into the home" {
    preview
    [ "$status" -eq 0 ]
    [ "$(readlink -f "$TARGET/.zshrc")" = "$(readlink -f "$DOTFILES_ROOT/zsh/.zshrc")" ]
    [ "$(readlink -f "$TARGET/.gitconfig")" = "$(readlink -f "$DOTFILES_ROOT/git/.gitconfig")" ]
    [ -f "$TARGET/.config/mise/config.toml" ]
}

@test "never links infrastructure directories" {
    preview
    [ "$status" -eq 0 ]
    for f in shared_vars.sh misewrapper.sh architecture.md adrs bootstrap.bats; do
        [ ! -e "$TARGET/$f" ]
    done
}

@test "creates ~/dev as a real directory, not a link into the repo" {
    preview
    [ "$status" -eq 0 ]
    [ -d "$TARGET/dev" ]
    [ ! -L "$TARGET/dev" ]
}

@test "creates ~/.local/bin as a real directory so installers don't write into the repo" {
    preview
    [ "$status" -eq 0 ]
    [ -d "$TARGET/.local/bin" ]
    [ ! -L "$TARGET/.local/bin" ]
    [ -L "$TARGET/.local/bin/secret" ]
}

@test "agent state directories stay out of the repo" {
    preview
    [ "$status" -eq 0 ]
    [ ! -L "$TARGET/.claude" ]
    [ ! -L "$TARGET/.pi" ]
    [ -L "$TARGET/.claude/settings.json" ]
}

@test "links nvim's config as a whole directory, so lazy-lock.json lands in the repo" {
    preview
    [ "$status" -eq 0 ]
    [ -L "$TARGET/.config/nvim" ]
    [ "$(readlink -f "$TARGET/.config/nvim")" = "$(readlink -f "$DOTFILES_ROOT/nvim/.config/nvim")" ]
}

@test "works from a checkout outside ~/.dotfiles" {
    local elsewhere=$(repo_copy)
    preview "$elsewhere"
    [ "$status" -eq 0 ]
    [ "$(readlink -f "$TARGET/.zshrc")" = "$(readlink -f "$elsewhere/zsh/.zshrc")" ]
    rm -rf "$elsewhere"
}

@test "previews machine-level steps instead of running them" {
    preview
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: mise install"* ]]
}

@test "never records trust; ~/dev is trusted by path instead" {
    preview
    [ "$status" -eq 0 ]
    [[ "$output" != *"mise trust"* ]]
}

@test "projects under ~/dev load without a trust prompt; configs elsewhere still need one" {
    preview
    [ "$status" -eq 0 ]
    mkdir -p "$TARGET/dev/alpha" "$TARGET/elsewhere"
    printf '[env]\nALPHA = "loaded"\n' > "$TARGET/dev/alpha/.mise.toml"
    printf '[env]\nELSEWHERE = "loaded"\n' > "$TARGET/elsewhere/.mise.toml"
    in_target() {
        ( cd "$1" && HOME="$TARGET" MISE_CONFIG_DIR="$TARGET/.config/mise" \
          MISE_STATE_DIR="$TARGET/.state" MISE_DATA_DIR="$TARGET/.data" MISE_CACHE_DIR="$TARGET/.cache" \
          MISE_OFFLINE=1 MISE_VERSION_CHECK=0 mise env 2>&1 )
    }
    run in_target "$TARGET/dev/alpha"
    [[ "$output" == *"ALPHA=loaded"* ]]
    run in_target "$TARGET/elsewhere"
    [[ "$output" == *"not trusted"* ]]
}

@test "previews GitHub login over SSH when not authenticated" {
    preview
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: gh auth login --hostname github.com --git-protocol ssh"* ]]
    [[ "$output" != *$'\ngh auth login'* ]]
}

@test "is safe to run twice, and the second run changes nothing" {
    preview
    [ "$status" -eq 0 ]
    preview
    [ "$status" -eq 0 ]
    [[ "$output" == *"all files are applied"* ]]
}

@test "a file already at a target stops the run before anything is linked" {
    local repo=$(repo_copy)
    local before=$(git -C "$repo" status --porcelain)
    echo "local" > "$TARGET/.gitconfig"
    preview "$repo"
    [ "$status" -ne 0 ]
    [ "$(cat "$TARGET/.gitconfig")" = "local" ]
    [ ! -e "$TARGET/.zshrc" ]
    [[ "$output" != *"would run: mise install"* ]]
    [ "$(git -C "$repo" status --porcelain)" = "$before" ]
    rm -rf "$repo"
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
    preview
    [ "$status" -eq 0 ]
    [[ "$output" == *"would clone kulesh/alpha"* ]]
    [[ "$output" != *"would clone kulesh/beta"* ]]
    [[ "$output" != *"would clone kulesh/dotfiles"* ]]
}

@test "creates ~/.ssh as a private real directory, with our settings in a real config file" {
    preview
    [ "$status" -eq 0 ]
    [ -d "$TARGET/.ssh" ]
    [ ! -L "$TARGET/.ssh" ]
    [ "$(mode "$TARGET/.ssh")" = "700" ]
    [ -f "$TARGET/.ssh/config" ]
    [ ! -L "$TARGET/.ssh/config" ]
    grep -q "Include ~/.config/colima/ssh_config" "$TARGET/.ssh/config"
    [ "$(( 0$(mode "$TARGET/.ssh/config") & 022 ))" -eq 0 ]
}

@test "lines other tools add to ~/.ssh/config survive the next run" {
    preview
    [ "$status" -eq 0 ]
    echo "Include ~/.orbstack/ssh/config" >> "$TARGET/.ssh/config"
    preview
    [ "$status" -eq 0 ]
    grep -q "Include ~/.orbstack/ssh/config" "$TARGET/.ssh/config"
    [ "$(grep -c "Include ~/.config/colima/ssh_config" "$TARGET/.ssh/config")" -eq 1 ]
}

@test "previews generating and uploading a key when logged in without one" {
    printf '#!/bin/sh\n[ "$1 $2" = "auth status" ] && exit 0\n' > "$STUBS/gh"
    preview
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: ssh-keygen -t ed25519 -f $TARGET/.ssh/id_ed25519"* ]]
    [[ "$output" == *"would run: gh ssh-key add $TARGET/.ssh/id_ed25519.pub"* ]]
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
    preview
    [ "$status" -eq 0 ]
    [[ "$output" == *"would run: gh ssh-key add $TARGET/.ssh/id_ed25519.pub --type signing"* ]]
    [[ "$output" == *"would write $TARGET/.config/git/allowed_signers"* ]]
}

@test "skips registering a signing key GitHub already has" {
    command -v ssh-keygen >/dev/null || skip "ssh-keygen not installed"
    mkdir -p -m 700 "$TARGET/.ssh"
    ssh-keygen -q -t ed25519 -N '' -f "$TARGET/.ssh/id_ed25519" -C test
    signing_gh_stub "$(cut -d' ' -f1,2 "$TARGET/.ssh/id_ed25519.pub")"
    preview
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

@test "the stowed git config pushes HTTPS GitHub clones over SSH, and fetches anonymously" {
    local repo=$(mktemp -d)
    git -C "$repo" init -q
    git -C "$repo" remote add origin https://github.com/kulesh/dotfiles.git
    export GIT_CONFIG_GLOBAL="$DOTFILES_ROOT/git/.gitconfig"
    [ "$(git -C "$repo" remote get-url --push origin)" = "git@github.com:kulesh/dotfiles.git" ]
    [ "$(git -C "$repo" remote get-url origin)" = "https://github.com/kulesh/dotfiles.git" ]
    rm -rf "$repo"
}

@test "every repo task is executable, or mise won't list or run it" {
    for task in "$DOTFILES_ROOT"/.mise/tasks/*; do
        [ -x "$task" ] || { echo "not executable: $task"; false; }
    done
}

@test "migrates a home linked by GNU Stow, writing nothing into the repo" {
    local repo=$(repo_copy)
    stowed_by_stow "$repo"
    [ -L "$TARGET/.config/nvim" ]
    local before=$(git -C "$repo" status --porcelain)
    preview "$repo"
    [ "$status" -eq 0 ]
    [[ "$output" == *"unstow"* ]]
    [ "$(readlink "$TARGET/.zshrc")" = "$repo/zsh/.zshrc" ]
    [ ! -L "$TARGET/.claude" ]
    [ ! -L "$TARGET/.ssh/config" ]
    grep -q "Include ~/.config/colima/ssh_config" "$TARGET/.ssh/config"
    [ "$(git -C "$repo" status --porcelain)" = "$before" ]
    rm -rf "$repo"
}

@test "a migrated home is left alone by the Stow cleanup" {
    local repo=$(repo_copy)
    stowed_by_stow "$repo"
    preview "$repo"
    [ "$status" -eq 0 ]
    preview "$repo"
    [ "$status" -eq 0 ]
    [[ "$output" != *"unstow"* ]]
    rm -rf "$repo"
}

@test "refuses to migrate when ~/.ssh is a link into the repo, and changes nothing" {
    local repo=$(repo_copy)
    stowed_by_stow "$repo"
    rm -r "$TARGET/.ssh"
    ln -s "$repo/ssh/.ssh" "$TARGET/.ssh"
    local before=$(git -C "$repo" status --porcelain)
    preview "$repo"
    [ "$status" -ne 0 ]
    [[ "$output" == *"SSH keys"* ]]
    [ -L "$TARGET/.ssh" ]
    [ -L "$TARGET/.zshrc" ]
    [ -f "$repo/ssh/.ssh/config" ]
    [ "$(git -C "$repo" status --porcelain)" = "$before" ]
    rm -rf "$repo"
}
