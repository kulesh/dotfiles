#!/usr/bin/env bats
# Acceptance tests for .mise/tasks/sync: two Macs sharing a dotfiles repo
# through a local bare remote standing in for GitHub.

load test_helper

setup() {
    WORK=$(mktemp -d)
    STUBS="$WORK/stubs"; mkdir "$STUBS"
    export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
    git config --global user.name Test
    git config --global user.email test@example.com
    git config --global init.defaultBranch main
    git config --global commit.gpgsign false

    # mise and lazygit record their calls instead of running.
    printf '#!/bin/sh\necho "mise $*" >> "%s/calls"\n' "$WORK" > "$STUBS/mise"
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
}

teardown() {
    rm -rf "$WORK"
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

@test "applies another Mac's changes and re-runs bootstrap" {
    other_mac_commits "three"
    sync
    [ "$status" -eq 0 ]
    [ "$(cat "$WORK/this/settings")" = "three" ]
    [[ "$output" == *"other: update settings"* ]]
    [ "$(calls)" = "mise bootstrap" ]
}

@test "commits local changes, named for this Mac and the files, and pushes them" {
    echo "local" >> "$WORK/this/settings"
    sync y
    [ "$status" -eq 0 ]
    [ "$(github_log | head -1)" = "$(hostname -s): update settings" ]
    [ -z "$(git -C "$WORK/this" status --porcelain)" ]
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
    [ "$(calls)" = "mise bootstrap" ]
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
    [ "$(calls)" = "mise bootstrap" ]
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
    [ "$(calls)" = "mise bootstrap" ]
}

@test "without lazygit, a conflict explains how to resolve it" {
    conflicting_edits
    rm "$STUBS/lazygit"
    PATH="$STUBS:/usr/bin:/bin" run zsh "$WORK/this/.mise/tasks/sync" </dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"edit and git add them"* ]]
}
