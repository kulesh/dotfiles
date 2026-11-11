#!/usr/bin/env bats
# Acceptance tests for .mise/tasks/sync: two Macs sharing a dotfiles repo
# through a local bare remote standing in for GitHub.

load test_helper

setup() {
    WORK=$(scratch)
    STUBS="$WORK/stubs"; mkdir "$STUBS"
    export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
    git config --global user.name Test
    git config --global user.email test@example.com
    git config --global init.defaultBranch main
    git config --global commit.gpgsign false

    # mise and lazygit record their calls instead of running. mise reports
    # $MISE_STUB_VERSION, and its bootstrap fails while $MISE_STUB_FAILS is set.
    cat > "$STUBS/mise" <<EOF
#!/bin/sh
[ "\$*" = --version ] && echo "\${MISE_STUB_VERSION:-2026.11.1} macos-arm64" && exit 0
echo "mise \$*" >> "$WORK/calls"
[ "\${1:-}" = bootstrap ] && [ -n "\$MISE_STUB_FAILS" ] && exit 1
exit 0
EOF
    printf '#!/bin/sh\necho lazygit >> "%s/calls"\n' "$WORK" > "$STUBS/lazygit"
    chmod +x "$STUBS/mise" "$STUBS/lazygit"

    git init -q --bare "$WORK/github.git"
    git clone -q "$WORK/github.git" "$WORK/this" 2>/dev/null
    mkdir -p "$WORK/this/.mise/tasks"
    cp "$DOTFILES_ROOT/.mise/tasks/sync" "$WORK/this/.mise/tasks/sync"
    printf 'one\ntwo\n' > "$WORK/this/settings"
    git -C "$WORK/this" add --all
    git -C "$WORK/this" commit -q -m seed
    git -C "$WORK/this" push -q -u origin main
    git clone -q "$WORK/github.git" "$WORK/other"
    # This Mac has applied what it has, as after an earlier dsync.
    git -C "$WORK/this" rev-parse HEAD > "$(git -C "$WORK/this" rev-parse --absolute-git-dir)/dotfiles-applied"
}


sync() {   # $1 = answer to the commit prompt
    PATH="$STUBS:$PATH" run zsh "$WORK/this/.mise/tasks/sync" <<< "${1:-}"
}

other_mac_commits() {   # $1 = new contents of settings
    printf '%s\n' "$1" > "$WORK/other/settings"
    git -C "$WORK/other" commit -q -am "other: update settings"
    git -C "$WORK/other" push -q
}

github_log() { git -C "$WORK/github.git" log --format=%s main; }
calls() { cat "$WORK/calls" 2>/dev/null || true; }

@test "does nothing when this Mac already matches GitHub" {
    sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"Already up to date"* ]]
    [ -z "$(calls)" ]
}

# dsync's job is to make the home match the repo, so it doesn't stop to ask
# before relinking (mise's "files: apply ~?"); a bootstrap run by hand asks.
@test "applies another Mac's changes and re-runs bootstrap, without asking" {
    other_mac_commits "three"
    sync
    [ "$status" -eq 0 ]
    [ "$(cat "$WORK/this/settings")" = "three" ]
    [[ "$output" == *"other: update settings"* ]]
    [ "$(calls)" = "mise bootstrap --yes" ]
}

@test "commits local changes, named for this Mac and the files, and pushes them" {
    echo "local" >> "$WORK/this/settings"
    sync y
    [ "$status" -eq 0 ]
    [ "$(github_log | head -1)" = "$(hostname -s): update settings" ]
    [ -z "$(git -C "$WORK/this" status --porcelain)" ]
}

@test "a new directory's files are each listed and named in the commit" {
    mkdir -p "$WORK/this/skills/task-manager"
    touch "$WORK/this/skills/task-manager/SKILL.md" "$WORK/this/skills/task-manager/README.md"
    sync y
    [ "$status" -eq 0 ]
    [[ "$output" == *"skills/task-manager/SKILL.md"* ]]
    [[ "$(github_log | head -1)" == *"README.md, SKILL.md"* ]]
}

@test "an empty answer means yes" {
    echo "local" >> "$WORK/this/settings"
    sync ""
    [ "$status" -eq 0 ]
    [ "$(github_log | head -1)" = "$(hostname -s): update settings" ]
}

@test "declining keeps local changes on this Mac and still pulls" {
    echo "local" > "$WORK/this/new-file"
    other_mac_commits "three"
    sync n
    [ "$status" -eq 0 ]
    [ "$(cat "$WORK/this/settings")" = "three" ]
    [ -f "$WORK/this/new-file" ]
    [ "$(github_log | head -1)" = "other: update settings" ]
}

@test "replays this Mac's commits on top of another Mac's and pushes" {
    echo "local" > "$WORK/this/new-file"
    git -C "$WORK/this" add new-file
    git -C "$WORK/this" commit -q -m "this: add new-file"
    other_mac_commits "three"
    sync
    [ "$status" -eq 0 ]
    [ "$(github_log | head -2 | tr '\n' ,)" = "this: add new-file,other: update settings," ]
    [ "$(calls)" = "mise bootstrap --yes" ]
}

conflicting_edits() {
    other_mac_commits "theirs"
    echo "mine" > "$WORK/this/settings"
    git -C "$WORK/this" commit -q -am "this: update settings"
}

@test "a conflict opens lazygit and pauses the sync if left unresolved" {
    conflicting_edits
    sync
    [ "$status" -ne 0 ]
    [[ "$output" == *"settings"* ]]
    [[ "$output" == *"run dsync again"* ]]
    [ "$(calls)" = "lazygit" ]
    [ "$(github_log | head -1)" = "other: update settings" ]
}

@test "resolving the conflict in lazygit finishes the sync" {
    conflicting_edits
    cat > "$STUBS/lazygit" <<'STUB'
#!/bin/sh
echo merged > settings && git add settings && GIT_EDITOR=true git rebase --continue >/dev/null
STUB
    sync
    [ "$status" -eq 0 ]
    [ "$(git -C "$WORK/github.git" show main:settings)" = "merged" ]
    [ "$(calls)" = "mise bootstrap --yes" ]
}

@test "aborting the rebase in lazygit pushes nothing" {
    conflicting_edits
    printf '#!/bin/sh\ngit rebase --abort\n' > "$STUBS/lazygit"
    sync
    [ "$status" -ne 0 ]
    [[ "$output" == *"nothing was pushed"* ]]
    [ "$(github_log | head -1)" = "other: update settings" ]
}

@test "re-running after resolving by hand finishes the rebase, pushes, and bootstraps" {
    conflicting_edits
    sync
    [ "$status" -ne 0 ]
    rm "$WORK/calls"
    echo merged > "$WORK/this/settings"
    git -C "$WORK/this" add settings
    sync
    [ "$status" -eq 0 ]
    [ "$(git -C "$WORK/github.git" show main:settings)" = "merged" ]
    [ "$(calls)" = "mise bootstrap --yes" ]
}

@test "without lazygit, a conflict explains how to resolve it" {
    conflicting_edits
    rm "$STUBS/lazygit"
    PATH="$STUBS:/usr/bin:/bin" run zsh "$WORK/this/.mise/tasks/sync" </dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"edit and git add them"* ]]
}

# =============================================================================
# Applying: bootstrap runs until this Mac has applied the commit it's on
# =============================================================================

@test "commits that arrived without dsync (a plain git pull) are applied" {
    other_mac_commits "three"
    git -C "$WORK/this" pull -q
    sync
    [ "$status" -eq 0 ]
    [ "$(calls)" = "mise bootstrap --yes" ]
    sync
    [ "$(calls)" = "mise bootstrap --yes" ]
    [[ "$output" == *"Already up to date"* ]]
}

@test "a bootstrap that failed is tried again by the next dsync" {
    other_mac_commits "three"
    MISE_STUB_FAILS=1 sync
    [ "$status" -ne 0 ]
    sync
    [ "$status" -eq 0 ]
    [ "$(calls)" = "mise bootstrap --yes"$'\n'"mise bootstrap --yes" ]
}

# The config's min_version (.mise.toml) can need a newer mise than this Mac
# has; an old mise warns, and dsync brings it up to date before bootstrapping.
@test "a mise older than the config needs is upgraded before bootstrap" {
    printf 'min_version = { soft = "2026.10.22" }\n' > "$WORK/other/.mise.toml"
    git -C "$WORK/other" add .mise.toml
    git -C "$WORK/other" commit -q -m "need a newer mise"
    git -C "$WORK/other" push -q
    MISE_STUB_VERSION=2026.10.21 sync
    [ "$status" -eq 0 ]
    [ "$(calls)" = "mise bootstrap packages upgrade brew:mise --yes"$'\n'"mise bootstrap --yes" ]
}

# A *.local file stays on the Mac that made it: dsync never offers it.
@test "the repo ignores *.local files, wherever they are" {
    git -C "$DOTFILES_ROOT" check-ignore -q dev/dev/docs/notes.md.local
    git -C "$DOTFILES_ROOT" check-ignore -q claude/.claude/skills/draft.local
    # Files only: a directory named *.local, like bin/.local, isn't ignored.
    run git -C "$DOTFILES_ROOT" check-ignore -q bin/.local/bin/newtool
    [ "$status" -ne 0 ]
}

# =============================================================================
# Uncommitted changes that conflict with another Mac's (git's autostash)
# =============================================================================

conflicting_change() {   # this Mac edits a line another Mac changed too
    other_mac_commits "theirs"
    printf 'mine\ntwo\n' > "$WORK/this/settings"
}

@test "kept local changes that conflict with another Mac's pause the sync before anything is applied" {
    conflicting_change
    sync n
    [ "$status" -ne 0 ]
    [[ "$output" == *"stash"* ]]
    [[ "$(calls)" == *lazygit* ]]
    [[ "$(calls)" != *bootstrap* ]]
}

@test "a sync never starts, or commits, while files are in conflict" {
    conflicting_change
    sync n
    sync y
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]
    [ "$(git -C "$WORK/this" log -1 --format=%s)" = "other: update settings" ]
}

# =============================================================================
# Reviewing what came in before it runs on this Mac
# =============================================================================

# Bootstrap runs what the repo says (the pre-dotfiles hook is plain shell),
# and anything that could push to the repo could write it: dsync shows what
# it's about to apply, and applies nothing if you say no.
@test "shows the incoming commits and files, and applies nothing when declined" {
    other_mac_commits "three"
    sync n
    [ "$status" -eq 0 ]
    [[ "$output" == *"other: update settings"* ]]
    [[ "$output" == *"settings"*"|"* ]]
    [[ "$output" == *"Not applied"* ]]
    [[ "$(calls)" != *bootstrap* ]]
    sync
    [ "$(calls)" = "mise bootstrap --yes" ]
}

# dsync commits into a public repo: files that are usually secrets never go.
@test "the repo ignores files that usually hold secrets, but not .env.example" {
    for file in .env .env.production app/.env.local certs/server.pem certs/server.key id_ed25519 auth.json credentials.json; do
        git -C "$DOTFILES_ROOT" check-ignore -q "dev/dev/docs/$file"
    done
    run git -C "$DOTFILES_ROOT" check-ignore -q mise/.config/mise/tasks/mkproject/fastapi/files/.env.example
    [ "$status" -ne 0 ]
}
