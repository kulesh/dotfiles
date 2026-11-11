#!/usr/bin/env bats
# Acceptance tests for the project commands: mise tasks under
# mise/.config/mise/tasks/project, run the way the shell aliases run them
# (mise -C / run project:<command>), in a scratch home whose ~/dev holds the
# projects as ~/dev/<org>/<repo>. Clones come from local bare repos standing
# in for GitHub; a stand-in gh reports the login kulesh, the default org.

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
    git config --global url."$HOME/github/".insteadOf git@github.com:
    # gh knows who you're logged in as; GH_NO_LOGIN makes it not.
    mkdir -p "$HOME/stubs"
    cat > "$HOME/stubs/gh" <<'EOF'
#!/bin/sh
[ -z "$GH_NO_LOGIN" ] && [ "$*" = "config get -h github.com user" ] && echo kulesh && exit 0
exit 1
EOF
    chmod +x "$HOME/stubs/gh"
    export PATH=$HOME/stubs:$PATH
    MINE=$DEV/kulesh
}


project() {   # project <command> [args...]
    run mise -C / run "project:$1" "${@:2}" </dev/null
}

github_repo() {   # github_repo <owner/name> [default branch]: a bare repo with one commit
    local seed=$HOME/seed/$1
    git init -q -b "${2:-main}" "$seed"
    git -C "$seed" commit -q --allow-empty -m init
    git clone -q --bare "$seed" "$HOME/github/$1.git"
}

push_commit() {   # push_commit <owner/name> <message>: a new commit on GitHub
    git -C "$HOME/seed/$1" commit -q --allow-empty -m "$2"
    git -C "$HOME/seed/$1" push -q "$HOME/github/$1.git" main
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
    [ -d "$MINE/demo/.git" ]
    [ "$(cat "$MINE/demo/README.md")" = "# demo" ]
    [ -f "$MINE/demo/.mise.toml" ]
    # One instructions file for every agent; Claude Code reads AGENTS.md
    # when there's no CLAUDE.md.
    [ -f "$MINE/demo/AGENTS.md" ]
    [ ! -e "$MINE/demo/CLAUDE.md" ]
    [ "$(followed)" = "$MINE/demo" ]
}

@test "mkproject puts a new project in your own org, or in the org you name" {
    project new demo
    [ -d "$DEV/kulesh/demo" ]
    project new acme/tool
    [ "$status" -eq 0 ]
    [ -d "$DEV/acme/tool/.git" ]
    [ "$(followed)" = "$DEV/acme/tool" ]
}

@test "names that reach outside ~/dev are refused, and nothing outside it is touched" {
    mkdir -p "$HOME/victim" && : > "$HOME/victim/.mise.toml"
    project new demo
    for name in ../victim kulesh/../../victim ..; do
        project remove "$name" --delete
        [ "$status" -ne 0 ]
        project workon "$name"
        [ "$status" -ne 0 ]
    done
    [ -d "$HOME/victim" ]
    for name in ../escape acme/../escape a/b/c .hidden; do
        project new "$name"
        [ "$status" -ne 0 ]
    done
    [ ! -e "$HOME/escape" ] && [ ! -e "$HOME/mise.toml" ] && [ ! -e "$DEV/.hidden" ]
}

@test "mkproject without a GitHub login asks for the org instead of guessing" {
    GH_NO_LOGIN=1 project new demo
    [ "$status" -ne 0 ]
    [[ "$output" == *"mkproject <org>/demo"* ]]
    [ -z "$(ls -A "$DEV")" ]
}

@test "mkproject --dry-run describes the project and creates nothing" {
    project new demo python --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"mkproject:python"* ]]
    [[ "$output" == *"$MINE/demo"* ]]
    [ ! -e "$MINE/demo" ]
    [ -z "$(followed)" ]
}

@test "mkproject refuses a name that's already a project" {
    mkdir -p "$MINE/demo"
    project new demo
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "mkproject with an unknown template lists the ones that exist" {
    project new demo nosuch
    [ "$status" -ne 0 ]
    [[ "$output" == *"python"* ]]
    [ ! -e "$MINE/demo" ]
}

@test "mkproject without a name shows how to use it" {
    project new
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: mkproject [org/]name [template]"* ]]
    [[ "$output" != *"mise ERROR"* ]]
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

@test "cloneproject clones into ~/dev/<owner>, keeps the repo's default branch, and moves the shell there" {
    github_repo kulesh/alpha trunk
    project clone kulesh/alpha
    [ "$status" -eq 0 ]
    [ "$(git -C "$MINE/alpha" branch --show-current)" = "trunk" ]
    [ -f "$MINE/alpha/.mise.toml" ]
    [ "$(followed)" = "$MINE/alpha" ]
}

@test "cloneproject puts someone else's repo under its owner, in lowercase" {
    github_repo crmne/ruby_llm
    # GitHub matches owners whatever their case.
    ln -s crmne "$HOME/github/Crmne"
    project clone Crmne/ruby_llm
    [ "$status" -eq 0 ]
    [ -d "$DEV/crmne/ruby_llm/.git" ]
}

@test "cloneproject accepts gh user/repo and GitHub URLs" {
    github_repo kulesh/alpha
    github_repo kulesh/beta
    project clone gh kulesh/alpha
    [ "$status" -eq 0 ]
    project clone https://github.com/kulesh/beta.git
    [ "$status" -eq 0 ]
    [ -d "$MINE/alpha/.git" ]
    [ -d "$MINE/beta/.git" ]
}

@test "cloneproject: a failed clone reports git's error and leaves nothing behind" {
    project clone kulesh/missing
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not appear to be a git repository"* || "$output" == *"Could not read from remote repository"* ]]
    [ ! -e "$MINE/missing" ]
    [ -z "$(followed)" ]
}

@test "cloneproject without a repo shows how to use it" {
    project clone
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: cloneproject <user>/<repo>"* ]]
    [[ "$output" != *"mise ERROR"* ]]
}

# =============================================================================
# An org is a mise monorepo: ~/dev/<org>/mise.toml
# =============================================================================

@test "an org's first project makes the org a monorepo: a task runs in every repo" {
    project new demo
    github_repo kulesh/alpha
    project clone kulesh/alpha
    grep -q '^monorepo_root = true' "$MINE/mise.toml"
    printf '[tasks.hello]\nrun = "echo hello from demo"\n' >> "$MINE/demo/.mise.toml"
    printf '[tasks.hello]\nrun = "echo hello from alpha"\n' >> "$MINE/alpha/.mise.toml"
    run mise -C "$MINE" run '//...:hello'
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello from demo"* ]]
    [[ "$output" == *"hello from alpha"* ]]
}

@test "an org's mise.toml is left alone once it exists" {
    mkdir -p "$MINE"
    printf '# mine\n' > "$MINE/mise.toml"
    project new demo
    [ "$(cat "$MINE/mise.toml")" = "# mine" ]
}

# =============================================================================
# lsprojects (project:list)
# =============================================================================

@test "lsprojects lists cloned and created projects by org, and nothing else" {
    github_repo kulesh/alpha
    github_repo crmne/ruby_llm
    project clone kulesh/alpha
    project clone crmne/ruby_llm
    project new demo
    mkdir -p "$MINE/not-a-project" "$DEV/.archive/kulesh/old"
    touch "$DEV/.archive/kulesh/old/.mise.toml"
    project list
    [ "$status" -eq 0 ]
    [[ "$output" == *"crmne"*"ruby_llm"*"kulesh"*"alpha"*"demo"* ]]
    [[ "$output" == *"↙ kulesh/alpha"* ]]
    [[ "$output" != *"not-a-project"* ]]
    [[ "$output" != *"old"* ]]
    [[ "$output" == *"3 projects in 2 orgs"* ]]
}

@test "lsprojects --type cloned shows only cloned projects" {
    github_repo kulesh/alpha
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
    mkdir -p "$MINE/demo/src/deep"
    project show --from "$MINE/demo/src/deep"
    [ "$status" -eq 0 ]
    [[ "$output" == *"kulesh/demo"* ]]
    [[ "$output" == *"main"* ]]
}

@test "showproject lists the project's own tools, one per line, and counts the inherited ones" {
    printf '[tools]\nuv = "0.5.0"\n' > "$DEV/.mise.toml"
    mkdir -p "$MINE/tooled"
    printf '[tools]\nnode = "20.1.0"\npython = "3.11.1"\n' > "$MINE/tooled/.mise.toml"
    MISE_TRUSTED_CONFIG_PATHS=$DEV project show --from "$MINE/tooled"
    [ "$status" -eq 0 ]
    local node=$'\n  node +20\.1\.0' python=$'\n  python +3\.11\.1'
    [[ "$output" =~ $node ]]
    [[ "$output" =~ $python ]]
    [[ "$output" != *"uv "* ]]
    [[ "$output" != *".mise.toml"* ]]
    [[ "$output" =~ \+\ [0-9]+\ inherited ]]
}

@test "showproject in ~/dev, an org or ~ says you're not in a project, though all hold mise config" {
    project new demo
    printf '[tools]\n' > "$DEV/.mise.toml"
    printf '[tools]\n' > "$HOME/.mise.toml"
    for dir in "$DEV" "$MINE" "$HOME"; do
        project show --from "$dir"
        [ "$status" -ne 0 ]
        [[ "$output" == *"Not in a project"* ]]
    done
    project show --from "$MINE/demo"
    [ "$status" -eq 0 ]
}

@test "showproject outside a project says so" {
    project show --from "$HOME"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Not in a project"* ]]
}

@test "cdproject moves the shell to the root of the project you're in" {
    project new demo
    rm -f "$DOTFILES_FOLLOW"
    mkdir -p "$MINE/demo/src/deep/pkg"
    # A config deeper in the repo (a package of its own) doesn't make it the root.
    : > "$MINE/demo/src/deep/pkg/.mise.toml"
    project root --from "$MINE/demo/src/deep/pkg"
    [ "$status" -eq 0 ]
    [ "$(followed)" = "$MINE/demo" ]
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
    [ "$(followed)" = "$MINE/demo" ]
}

@test "workon takes org/repo, and a bare repo name only while it's unambiguous" {
    project new demo
    project new acme/demo
    project new acme/tool
    rm -f "$DOTFILES_FOLLOW"
    project workon tool
    [ "$(followed)" = "$DEV/acme/tool" ]
    project workon acme/demo
    [ "$(followed)" = "$DEV/acme/demo" ]
    rm -f "$DOTFILES_FOLLOW"
    project workon demo
    [ "$status" -ne 0 ]
    [[ "$output" == *"acme/demo"*"kulesh/demo"* ]]
    [ -z "$(followed)" ]
}

@test "workon -s marks the project sandboxed" {
    project new demo
    project workon demo -s
    [ "$status" -eq 0 ]
    [ -f "$MINE/demo/.sandbox" ]
}

@test "workon an unknown project says so and goes nowhere" {
    project workon nosuch
    [ "$status" -ne 0 ]
    [[ "$output" == *"nosuch"* ]]
    [ -z "$(followed)" ]
}

@test "workon without a name, outside a terminal, shows how to use it and goes nowhere" {
    project workon
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: workon <name>"* ]]
    [[ "$output" != *"mise ERROR"* ]]
    [ -z "$(followed)" ]
}

@test "the project picker (workon, rmproject) previews each project with showproject" {
    project new demo
    # A stand-in fzf: runs the preview it was given for the first project,
    # as fzf would on the highlighted line, then picks that project.
    cat > "$HOME/stubs/fzf" <<'EOF'
#!/bin/sh
first=$(head -n 1)
while [ $# -gt 0 ]; do
    case $1 in --preview) preview=$2; shift ;; --preview=*) preview=${1#--preview=} ;; esac
    shift
done
[ -n "$preview" ] && sh -c "$(printf '%s' "$preview" | sed "s|{}|'$first'|g")" > "$HOME/preview" 2>&1
echo "$first"
EOF
    chmod +x "$HOME/stubs/fzf"
    # The pickers open only in a terminal.
    PATH=$HOME/stubs:$PATH run python3 -c 'import pty, sys; pty.spawn(sys.argv[1:])' \
        mise -C / run project:workon </dev/null
    [ "$(followed)" = "$MINE/demo" ]
    [[ "$(cat "$HOME/preview")" == *"kulesh/demo"*"Git"* ]]
}

@test "workon completes project names, and only projects; a name in two orgs completes with its org" {
    project new demo
    project new tool
    project new acme/tool
    mkdir -p "$MINE/not-a-project"
    local candidates=$(completions 'mise -C / run project:workon ')
    [[ $'\n'"$candidates"$'\n' == *$'\n'demo$'\n'* ]]
    [[ "$candidates" == *acme/tool* && "$candidates" == *kulesh/tool* ]]
    [[ "$candidates" != *not-a-project* ]]
}

# =============================================================================
# updateproject (project:update)
# =============================================================================

@test "updateproject pulls new commits, by name or from inside the project" {
    github_repo kulesh/alpha
    project clone kulesh/alpha
    push_commit kulesh/alpha second
    project update alpha
    [ "$status" -eq 0 ]
    [ "$(git -C "$MINE/alpha" log -1 --format=%s)" = "second" ]
    push_commit kulesh/alpha third
    project update --from "$MINE/alpha"
    [ "$status" -eq 0 ]
    [ "$(git -C "$MINE/alpha" log -1 --format=%s)" = "third" ]
}

@test "updateproject pulls from the branch's own upstream; a branch without one says so" {
    github_repo kulesh/alpha
    project clone kulesh/alpha
    git -C "$MINE/alpha" checkout -q -b work --track origin/main
    push_commit kulesh/alpha second
    project update alpha
    [ "$status" -eq 0 ]
    [ "$(git -C "$MINE/alpha" log -1 --format=%s)" = "second" ]
    git -C "$MINE/alpha" checkout -q -b local-only
    project update alpha
    [ "$status" -ne 0 ]
    [[ "$output" == *"no upstream"* ]]
}

@test "updateproject refuses a project with uncommitted changes" {
    github_repo kulesh/alpha
    project clone kulesh/alpha
    echo change > "$MINE/alpha/file"
    git -C "$MINE/alpha" add file
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

@test "rmproject archives the project into ~/dev/.archive/<org>" {
    project new demo
    project remove demo
    [ "$status" -eq 0 ]
    [ ! -e "$MINE/demo" ]
    [ -d "$DEV/.archive/kulesh/demo/.git" ]
}

@test "rmproject --delete removes it for good" {
    project new demo
    project remove demo --delete
    [ "$status" -eq 0 ]
    [ ! -e "$MINE/demo" ]
    [ ! -e "$DEV/.archive/kulesh/demo" ]
}

@test "rmproject from inside the project moves the shell to its org" {
    project new demo
    rm -f "$DOTFILES_FOLLOW"
    project remove demo --from "$MINE/demo/src"
    [ "$status" -eq 0 ]
    [ "$(followed)" = "$MINE" ]
}

@test "rmproject without a name, outside a terminal, shows how to use it and removes nothing" {
    project new demo
    project remove
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: rmproject <name> [--delete]"* ]]
    [[ "$output" != *"mise ERROR"* ]]
    [ -d "$MINE/demo" ]
}

@test "rmproject an unknown project says so and changes nothing" {
    project new demo
    project remove nosuch
    [ "$status" -ne 0 ]
    [[ "$output" == *"nosuch"* ]]
    [ -d "$MINE/demo" ]
}

# =============================================================================
# Migrating ~/dev/<repo> to ~/dev/<org>/<repo> (project:migrate)
# =============================================================================

old_layout() {   # projects as the flat layout left them, one per kind
    github_repo kulesh/alpha
    github_repo kulesh/kulesh
    github_repo crmne/ruby_llm
    git clone -q git@github.com:kulesh/alpha.git "$DEV/alpha"
    # A repo named like its owner: ~/dev/kulesh is both it and the new org.
    git clone -q git@github.com:kulesh/kulesh.git "$DEV/kulesh"
    git clone -q git@github.com:crmne/ruby_llm.git "$DEV/ruby_llm"
    mkdir -p "$DEV/scratchpad"
    for dir in alpha kulesh ruby_llm scratchpad; do : > "$DEV/$dir/.mise.toml"; done
    touch "$DEV/kulesh/.sandbox"
}

@test "migrate moves each project under its GitHub owner, local ones under yours" {
    old_layout
    project migrate
    [ "$status" -eq 0 ]
    [ -d "$DEV/kulesh/alpha/.git" ]
    [ -d "$DEV/kulesh/kulesh/.git" ]
    [ -f "$DEV/kulesh/kulesh/.sandbox" ]
    [ -d "$DEV/crmne/ruby_llm/.git" ]
    [ -f "$DEV/kulesh/scratchpad/.mise.toml" ]
    grep -q '^monorepo_root = true' "$DEV/kulesh/mise.toml"
    grep -q '^monorepo_root = true' "$DEV/crmne/mise.toml"
    [ ! -e "$DEV/alpha" ]
    [ ! -e "$DEV/ruby_llm" ]
}

@test "migrate --dry-run lists the moves and moves nothing" {
    old_layout
    project migrate --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"$DEV/ruby_llm"*"$DEV/crmne/ruby_llm"* ]]
    [ -d "$DEV/ruby_llm/.git" ]
    [ ! -e "$DEV/crmne" ]
}

@test "migrate on a migrated ~/dev has nothing to do" {
    old_layout
    project migrate
    project migrate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to migrate"* ]]
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
