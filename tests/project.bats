#!/usr/bin/env bats
# Acceptance tests for the project commands: mise tasks under
# mise/.config/mise/tasks/project, run the way the shell aliases run them
# (mise -C / run project:<command>), in a scratch home whose ~/dev holds the
# projects. Clones come from local bare repos standing in for GitHub.

load test_helper

setup() {
    command -v mise >/dev/null || skip "mise not installed"
    export HOME=$(scratch)
    export DEV=$HOME/dev
    mkdir -p "$DEV"
    # mise reads the repo's global config and tasks directly.
    export MISE_CONFIG_DIR="$DOTFILES_ROOT/mise/.config/mise"
    export MISE_STATE_DIR=$HOME/.state MISE_DATA_DIR=$HOME/.data MISE_CACHE_DIR=$HOME/.cache
    export MISE_OFFLINE=1 MISE_VERSION_CHECK=0 MISE_AUTO_INSTALL=0
    # Where a command leaves the directory the shell should move to.
    export DOTFILES_FOLLOW=$HOME/follow
    # GitHub is a directory of bare repos; commits need an identity, not a key.
    export GIT_CONFIG_GLOBAL=$HOME/gitconfig
    git config --global user.name Test
    git config --global user.email test@example.com
    git config --global commit.gpgsign false
    git config --global init.defaultBranch main
    git config --global url."$HOME/github/".insteadOf git@github.com:kulesh/
}


project() {   # project <command> [args...]
    run mise -C / run "project:$1" "${@:2}" </dev/null
}

github_repo() {   # github_repo <name> [default branch]: a bare repo with one commit
    local seed=$HOME/seed-$1
    git init -q -b "${2:-main}" "$seed"
    git -C "$seed" commit -q --allow-empty -m init
    git clone -q --bare "$seed" "$HOME/github/$1.git"
}

followed() { cat "$DOTFILES_FOLLOW" 2>/dev/null || true; }

completions() {   # the candidates zsh would offer for a command line
    ( cd "$DEV" && mise __complete_word__ --shell zsh --line "$1" 2>/dev/null | cut -f1 )
}

# =============================================================================
# mkproject (project:new)
# =============================================================================

@test "mkproject creates a project from the base template and moves the shell there" {
    project new demo
    [ "$status" -eq 0 ]
    [ -d "$DEV/demo/.git" ]
    [ "$(cat "$DEV/demo/README.md")" = "# demo" ]
    [ -f "$DEV/demo/.mise.toml" ]
    [ -f "$DEV/demo/CLAUDE.md" ]
    [ -f "$DEV/demo/AGENTS.md" ]
    [ "$(followed)" = "$DEV/demo" ]
}

@test "mkproject --dry-run describes the project and creates nothing" {
    project new demo python --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"mkproject:python"* ]]
    [ ! -e "$DEV/demo" ]
    [ -z "$(followed)" ]
}

@test "mkproject refuses a name that's already a project" {
    mkdir -p "$DEV/demo"
    project new demo
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "mkproject with an unknown template lists the ones that exist" {
    project new demo nosuch
    [ "$status" -ne 0 ]
    [[ "$output" == *"python"* ]]
    [ ! -e "$DEV/demo" ]
}

@test "mkproject completes template names" {
    [[ "$(completions 'mise -C / run project:new demo ')" == *python* ]]
}

@test "list_project_types lists every template" {
    project types
    [ "$status" -eq 0 ]
    for template in base python fastapi ruby rails rust typescript convex; do
        [[ "$output" == *"$template"* ]]
    done
}

# =============================================================================
# cloneproject (project:clone)
# =============================================================================

@test "cloneproject clones into ~/dev, keeps the repo's default branch, and moves the shell there" {
    github_repo alpha trunk
    project clone kulesh/alpha
    [ "$status" -eq 0 ]
    [ "$(git -C "$DEV/alpha" branch --show-current)" = "trunk" ]
    [ -f "$DEV/alpha/.mise.toml" ]
    [ "$(followed)" = "$DEV/alpha" ]
}

@test "cloneproject accepts gh user/repo and GitHub URLs" {
    github_repo alpha
    github_repo beta
    project clone gh kulesh/alpha
    [ "$status" -eq 0 ]
    project clone https://github.com/kulesh/beta.git
    [ "$status" -eq 0 ]
    [ -d "$DEV/alpha/.git" ]
    [ -d "$DEV/beta/.git" ]
}

@test "cloneproject: a failed clone reports git's error and leaves nothing behind" {
    project clone kulesh/missing
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not appear to be a git repository"* || "$output" == *"Could not read from remote repository"* ]]
    [ ! -e "$DEV/missing" ]
    [ -z "$(followed)" ]
}

# =============================================================================
# lsprojects (project:list)
# =============================================================================

@test "lsprojects lists cloned and created projects, and nothing else" {
    github_repo alpha
    project clone kulesh/alpha
    project new demo
    mkdir -p "$DEV/not-a-project" "$DEV/.archive/old"
    touch "$DEV/.archive/old/.mise.toml"
    project list
    [ "$status" -eq 0 ]
    [[ "$output" == *"kulesh/alpha"* ]]
    [[ "$output" == *"demo"* ]]
    [[ "$output" != *"not-a-project"* ]]
    [[ "$output" != *"old"* ]]
}

@test "lsprojects --type cloned shows only cloned projects" {
    github_repo alpha
    project clone kulesh/alpha
    project new demo
    project list --type cloned
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" != *"demo"* ]]
}

# =============================================================================
# showproject (project:show) and cdproject (project:root)
# =============================================================================

@test "showproject describes the project you're in, from any directory inside it" {
    project new demo
    mkdir -p "$DEV/demo/src/deep"
    project show --from "$DEV/demo/src/deep"
    [ "$status" -eq 0 ]
    [[ "$output" == *"demo"* ]]
    [[ "$output" == *"main"* ]]
}

@test "showproject outside a project says so" {
    project show --from "$HOME"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Not in a project"* ]]
}

@test "cdproject moves the shell to the root of the project you're in" {
    project new demo
    rm -f "$DOTFILES_FOLLOW"
    mkdir -p "$DEV/demo/src/deep"
    project root --from "$DEV/demo/src/deep"
    [ "$status" -eq 0 ]
    [ "$(followed)" = "$DEV/demo" ]
}

@test "cdproject outside a project says so and goes nowhere" {
    project root --from "$HOME"
    [ "$status" -ne 0 ]
    [ -z "$(followed)" ]
}

# =============================================================================
# workon (project:workon)
# =============================================================================

@test "workon moves the shell to the project" {
    project new demo
    rm -f "$DOTFILES_FOLLOW"
    project workon demo
    [ "$status" -eq 0 ]
    [ "$(followed)" = "$DEV/demo" ]
}

@test "workon -s marks the project sandboxed" {
    project new demo
    project workon demo -s
    [ "$status" -eq 0 ]
    [ -f "$DEV/demo/.sandbox" ]
}

@test "workon an unknown project says so and goes nowhere" {
    project workon nosuch
    [ "$status" -ne 0 ]
    [[ "$output" == *"nosuch"* ]]
    [ -z "$(followed)" ]
}

@test "workon completes project names, and only projects" {
    project new demo
    mkdir -p "$DEV/not-a-project"
    local candidates=$(completions 'mise -C / run project:workon ')
    [[ "$candidates" == *demo* ]]
    [[ "$candidates" != *not-a-project* ]]
}

# =============================================================================
# updateproject (project:update)
# =============================================================================

@test "updateproject pulls new commits, by name or from inside the project" {
    github_repo alpha
    project clone kulesh/alpha
    git -C "$HOME/seed-alpha" commit -q --allow-empty -m "second"
    git -C "$HOME/seed-alpha" push -q "$HOME/github/alpha.git" main
    project update alpha
    [ "$status" -eq 0 ]
    [ "$(git -C "$DEV/alpha" log -1 --format=%s)" = "second" ]
    git -C "$HOME/seed-alpha" commit -q --allow-empty -m "third"
    git -C "$HOME/seed-alpha" push -q "$HOME/github/alpha.git" main
    project update --from "$DEV/alpha"
    [ "$status" -eq 0 ]
    [ "$(git -C "$DEV/alpha" log -1 --format=%s)" = "third" ]
}

@test "updateproject refuses a project with uncommitted changes" {
    github_repo alpha
    project clone kulesh/alpha
    echo change > "$DEV/alpha/file"
    git -C "$DEV/alpha" add file
    project update alpha
    [ "$status" -ne 0 ]
    [[ "$output" == *"uncommitted"* ]]
}

@test "updateproject on a project with no remote says so" {
    project new demo
    project update demo
    [ "$status" -ne 0 ]
    [[ "$output" == *"remote"* ]]
}

# =============================================================================
# rmproject (project:remove)
# =============================================================================

@test "rmproject archives the project into ~/dev/.archive" {
    project new demo
    project remove demo
    [ "$status" -eq 0 ]
    [ ! -e "$DEV/demo" ]
    [ -d "$DEV/.archive/demo/.git" ]
}

@test "rmproject --delete removes it for good" {
    project new demo
    project remove demo --delete
    [ "$status" -eq 0 ]
    [ ! -e "$DEV/demo" ]
    [ ! -e "$DEV/.archive/demo" ]
}

@test "rmproject from inside the project moves the shell to ~/dev" {
    project new demo
    rm -f "$DOTFILES_FOLLOW"
    project remove demo --from "$DEV/demo"
    [ "$status" -eq 0 ]
    [ "$(followed)" = "$DEV" ]
}

@test "rmproject an unknown project says so and changes nothing" {
    project new demo
    project remove nosuch
    [ "$status" -ne 0 ]
    [[ "$output" == *"nosuch"* ]]
    [ -d "$DEV/demo" ]
}

# =============================================================================
# The shell side
# =============================================================================

@test "the shell follows a command to the directory it names, once" {
    mkdir -p "$HOME/target"
    run zsh -c '
        source "$1/lib/follow.zsh"
        print -r -- "$2" > "$DOTFILES_FOLLOW"
        _dotfiles_follow
        print -r -- "$PWD"
        [[ ! -e $DOTFILES_FOLLOW ]] && echo consumed
    ' _ "$DOTFILES_ROOT" "$HOME/target"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$HOME/target" ]
    [ "${lines[1]}" = "consumed" ]
}

@test "an activated shell gets the project commands as aliases" {
    run mise hook-env -s zsh
    for command in mkproject cloneproject lsprojects showproject updateproject rmproject workon cdproject list_project_types; do
        [[ "$output" == *"alias $command='"* ]]
    done
}
