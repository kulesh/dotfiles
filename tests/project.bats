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
    export DEV=$HOME/dev PROJECT_DIR=$HOME/dev
    mkdir -p "$DEV"
    # mise reads the repo's global config and tasks directly.
    export MISE_CONFIG_DIR="$DOTFILES_ROOT/mise/.config/mise"
    export MISE_STATE_DIR=$HOME/.state MISE_DATA_DIR=$HOME/.data MISE_CACHE_DIR=$HOME/.cache
    export MISE_OFFLINE=1 MISE_VERSION_CHECK=0 MISE_AUTO_INSTALL=0
    # Bootstrap writes which orgs are trusted on each Mac; here, all of ~/dev.
    export MISE_TRUSTED_CONFIG_PATHS=$DEV
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
        project remove "$name" --delete --yes
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

# PROJECT_DIR (include/shared_vars.sh, exported by .zshenv) is the one
# setting for where projects live; bootstrap clones there too.
@test "projects live wherever PROJECT_DIR points" {
    export PROJECT_DIR=$HOME/code MISE_TRUSTED_CONFIG_PATHS=$HOME/code
    mkdir -p "$PROJECT_DIR"
    project new demo
    [ "$status" -eq 0 ]
    [ -d "$PROJECT_DIR/kulesh/demo/.git" ]
    [ ! -e "$DEV/kulesh" ]
    project list
    [[ "$output" == *"in $PROJECT_DIR"* && "$output" == *demo* ]]
}

@test "mkproject without a GitHub login asks for the org instead of guessing" {
    GH_NO_LOGIN=1 project new demo
    [ "$status" -ne 0 ]
    [[ "$output" == *"mkproject <org>/demo"* ]]
    [ -z "$(ls -A "$DEV")" ]
}

@test "a template step that fails stops mkproject, which says so instead of Created" {
    local git=$(command -v git)
    printf '#!/bin/sh\n[ "$1" = init ] && { echo "git init: failed" >&2; exit 1; }\nexec %s "$@"\n' "$git" > "$HOME/stubs/git"
    chmod +x "$HOME/stubs/git"
    project new demo
    [ "$status" -ne 0 ]
    [[ "$output" == *"mkproject:base failed"* ]]
    [[ "$output" != *"Created"* ]]
}

@test "a failed mkproject outside a terminal leaves the partial project where it is" {
    local git=$(command -v git)
    printf '#!/bin/sh\n[ "$1" = init ] && exit 1\nexec %s "$@"\n' "$git" > "$HOME/stubs/git"
    chmod +x "$HOME/stubs/git"
    project new demo
    [ "$status" -ne 0 ]
    [ -d "$MINE/demo" ]
    [ ! -e "$DEV/.archive" ]
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

@test "mkproject completes template names, and only templates" {
    local candidates=$(completions 'mise -C / run project:new demo ')
    [[ "$candidates" == *python* ]]
    [[ "$candidates" != *tools:* ]]
}

@test "the templates are named once: list_project_types --names, without the tool steps" {
    run --separate-stderr mise -C / run project:types --names
    [ "$status" -eq 0 ]
    [ "$output" = $'base\nconvex\nfastapi\npython\nrails\nruby\nrust\ntypescript' ]
    project types
    [[ "$output" != *tools:* ]]
    project new demo tools:python
    [ "$status" -ne 0 ]
    [[ "$output" == *"No template 'tools:python'"* ]]
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
    [ "$(followed)" = "$MINE/alpha" ]
}

@test "a clone stays as git made it: no config added, nothing to commit, still a project" {
    github_repo kulesh/alpha
    project clone kulesh/alpha
    [ ! -e "$MINE/alpha/.mise.toml" ]
    [ -z "$(git -C "$MINE/alpha" status --porcelain)" ]
    project list
    [[ "$output" == *"alpha"* ]]
    project show --from "$MINE/alpha"
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]]
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
# An org is a plain folder; config you put in it reaches all its repos
# =============================================================================

@test "an org is a plain folder: its first project writes no config into it" {
    project new demo
    github_repo kulesh/alpha
    project clone kulesh/alpha
    [ -z "$(ls -A "$MINE" | grep -v -x -e demo -e alpha)" ]
}

@test "config you put in an org reaches every repo in it, and is left alone" {
    mkdir -p "$MINE"
    printf '[env]\nORG_WIDE = "yes"\n' > "$MINE/mise.toml"
    project new demo
    [ "$(cat "$MINE/mise.toml")" = $'[env]\nORG_WIDE = "yes"' ]
    run mise -C "$MINE/demo" env -s bash
    [[ "$output" == *"ORG_WIDE=yes"* ]]
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

# An org name with a trailing slash, or an org folder you're in, updates
# every repo in it: one fetch round, one table, one question, fast-forwards
# only. A repo that can't fast-forward is listed with the reason and left as
# it is.
@test "updateproject <org>/ fast-forwards every repo in the org, and says why it skipped the rest" {
    for repo in alpha beta dirty; do github_repo kulesh/$repo; project clone kulesh/$repo; done
    github_repo acme/other
    project clone acme/other
    project new demo   # local, nothing to pull from
    for repo in kulesh/alpha kulesh/beta kulesh/dirty acme/other; do push_commit $repo second; done
    echo change > "$MINE/dirty/file"
    git -C "$MINE/dirty" add file
    project update kulesh/
    [ "$status" -eq 0 ]
    [ "$(git -C "$MINE/alpha" log -1 --format=%s)" = "second" ]
    [ "$(git -C "$MINE/beta" log -1 --format=%s)" = "second" ]
    [ "$(git -C "$MINE/dirty" log -1 --format=%s)" = "init" ]
    [ "$(git -C "$DEV/acme/other" log -1 --format=%s)" = "init" ]
    [[ "$output" == *"dirty"*"uncommitted"* ]]
    [[ "$output" == *"demo"*"no upstream"* ]]
    [[ "$output" == *"Updated 2"* ]]
}

@test "updateproject in an org folder updates that org" {
    github_repo kulesh/alpha
    project clone kulesh/alpha
    push_commit kulesh/alpha second
    project update --from "$MINE"
    [ "$status" -eq 0 ]
    [ "$(git -C "$MINE/alpha" log -1 --format=%s)" = "second" ]
}

@test "updateproject on an org leaves a diverged repo alone and updates the others" {
    for repo in alpha beta; do github_repo kulesh/$repo; project clone kulesh/$repo; done
    push_commit kulesh/alpha theirs
    push_commit kulesh/beta second
    git -C "$MINE/alpha" commit -q --allow-empty -m mine
    project update kulesh/
    [ "$status" -eq 0 ]
    [ "$(git -C "$MINE/alpha" log -1 --format=%s)" = "mine" ]
    [ "$(git -C "$MINE/beta" log -1 --format=%s)" = "second" ]
    [[ "$output" == *"alpha"*"diverged"* ]]
}

@test "updateproject on an org that's up to date says so and asks nothing" {
    github_repo kulesh/alpha
    project clone kulesh/alpha
    project update kulesh/
    [ "$status" -eq 0 ]
    [[ "$output" == *"up to date"* ]]
    [[ "$output" != *"Fast-forward"* ]]
}

@test "updateproject on an org that doesn't exist says so" {
    project update nosuch/
    [ "$status" -ne 0 ]
    [[ "$output" == *"No org 'nosuch'"* ]]
}

@test "updateproject completes orgs, with a trailing slash, as well as projects" {
    project new demo
    project new acme/tool
    local candidates=$(completions 'mise -C / run project:update ')
    [[ $'\n'"$candidates"$'\n' == *$'\n'kulesh/$'\n'* ]]
    [[ $'\n'"$candidates"$'\n' == *$'\n'acme/$'\n'* ]]
    [[ $'\n'"$candidates"$'\n' == *$'\n'demo$'\n'* ]]
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
    project remove demo --delete --yes
    [ "$status" -eq 0 ]
    [ ! -e "$MINE/demo" ]
    [ ! -e "$DEV/.archive/kulesh/demo" ]
}

@test "outside a terminal, rmproject --delete deletes only with --yes" {
    project new demo
    project remove demo --delete
    [ -d "$MINE/demo" ]
    [[ "$output" == *"Cancelled"* ]]
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
