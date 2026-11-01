#!/usr/bin/env bats
# Tests for the helpers the project tasks share:
# mise/.config/mise/tasks/project/_lib.zsh

load test_helper

LIB="$DOTFILES_ROOT/mise/.config/mise/tasks/project/_lib.zsh"

lib() {   # run a helper from _lib.zsh: lib <function> [args...]
    run zsh -c 'source "$1"; shift; "$@"' _ "$LIB" "$@"
}

# =============================================================================
# parse_github_repo: what a user types → "clone URL|project name"
# =============================================================================

@test "parse_github_repo: user/repo" {
    lib parse_github_repo "kulesh/dotfiles"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:kulesh/dotfiles.git|dotfiles" ]
}

@test "parse_github_repo: gh user/repo, the older form" {
    lib parse_github_repo "gh" "kulesh/dotfiles"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:kulesh/dotfiles.git|dotfiles" ]
}

@test "parse_github_repo: HTTPS URL with and without .git, and with a trailing slash" {
    for url in https://github.com/kulesh/dotfiles.git https://github.com/kulesh/dotfiles https://github.com/kulesh/dotfiles/; do
        lib parse_github_repo "$url"
        [ "$status" -eq 0 ]
        [ "$output" = "git@github.com:kulesh/dotfiles.git|dotfiles" ]
    done
}

@test "parse_github_repo: SSH URL with and without .git" {
    lib parse_github_repo "git@github.com:kulesh/dotfiles.git"
    [ "$output" = "git@github.com:kulesh/dotfiles.git|dotfiles" ]
    lib parse_github_repo "git@github.com:kulesh/dotfiles"
    [ "$status" -eq 0 ]
    [[ "$output" == *"|dotfiles" ]]
}

@test "parse_github_repo: repo names with hyphens and dots" {
    lib parse_github_repo "user/my-cool.repo"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:user/my-cool.repo.git|my-cool.repo" ]
}

@test "parse_github_repo: rejects anything else" {
    for bad in "not-a-url" "" "just-a-user" "a/b/c"; do
        lib parse_github_repo "$bad"
        [ "$status" -eq 1 ]
    done
    lib parse_github_repo "gh" "just-a-user"
    [ "$status" -eq 1 ]
}

# =============================================================================
# project_root: the nearest directory with a mise config
# =============================================================================

@test "project_root: finds the config in the directory itself or any parent" {
    local tmp=$(scratch)
    local real=$(cd "$tmp" && pwd -P)
    touch "$tmp/.mise.toml"
    mkdir -p "$tmp/sub/deep"
    lib project_root "$tmp"
    [ "$output" = "$real" ]
    lib project_root "$tmp/sub/deep"
    [ "$status" -eq 0 ]
    [ "$output" = "$real" ]
}

@test "project_root: fails outside any project" {
    local tmp=$(scratch)
    lib project_root "$tmp"
    [ "$status" -eq 1 ]
}

# =============================================================================
# Agent docs: CLAUDE.md and AGENTS.md from a shared header plus the template's part
# =============================================================================

@test "escape_sed: escapes ampersands and backslashes, passes the rest" {
    lib escape_sed 'foo&bar'
    [ "$output" = 'foo\&bar' ]
    lib escape_sed 'foo\bar'
    [ "$output" = 'foo\\bar' ]
    lib escape_sed 'my-project'
    [ "$output" = "my-project" ]
}

@test "apply_placeholders: fills in the project and module names" {
    local tmp=$(scratch)
    printf 'Welcome to <project-name>!\nimport <module_name>\n' > "$tmp/test.md"
    lib apply_placeholders "$tmp/test.md" "my-cool-api"
    [ "$status" -eq 0 ]
    [ "$(cat "$tmp/test.md")" = $'Welcome to my-cool-api!\nimport my_cool_api' ]
}

@test "apply_placeholders: a missing file is not an error" {
    lib apply_placeholders /nonexistent/file.md project
    [ "$status" -eq 0 ]
}

@test "write_agent_docs: every template gets both files, with placeholders filled" {
    for template in base python fastapi ruby rails rust typescript convex; do
        local tmp=$(scratch)
        lib write_agent_docs "$tmp" "$template" "test-project"
        [ "$status" -eq 0 ]
        [ -f "$tmp/CLAUDE.md" ]
        [ -f "$tmp/AGENTS.md" ]
        grep -q "Assistant's Role" "$tmp/CLAUDE.md"
        [ -z "$(grep '<project-name>' "$tmp/CLAUDE.md")" ]
    done
}
