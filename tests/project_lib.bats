#!/usr/bin/env bats
# Tests for the helpers the project tasks share:
# mise/.config/mise/tasks/project/_lib.zsh

load test_helper

LIB="$DOTFILES_ROOT/mise/.config/mise/tasks/project/_lib.zsh"
HELPERS="$DOTFILES_ROOT/mise/.config/mise/tasks/mkproject/_shared/template_helpers.sh"

# The helpers read ~/dev; never the real one.
setup() {
    export HOME=$(scratch)
}

lib() {   # run a helper from _lib.zsh: lib <function> [args...]
    run zsh -c 'source "$1"; shift; "$@"' _ "$LIB" "$@"
}

# =============================================================================
# parse_github_repo: what a user types → "clone URL|owner/repo"
# =============================================================================

@test "parse_github_repo: user/repo" {
    lib parse_github_repo "kulesh/dotfiles"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:kulesh/dotfiles.git|kulesh/dotfiles" ]
}

@test "parse_github_repo: HTTPS URL with and without .git, and with a trailing slash" {
    for url in https://github.com/kulesh/dotfiles.git https://github.com/kulesh/dotfiles https://github.com/kulesh/dotfiles/; do
        lib parse_github_repo "$url"
        [ "$status" -eq 0 ]
        [ "$output" = "git@github.com:kulesh/dotfiles.git|kulesh/dotfiles" ]
    done
}

@test "parse_github_repo: SSH URL with and without .git" {
    lib parse_github_repo "git@github.com:kulesh/dotfiles.git"
    [ "$output" = "git@github.com:kulesh/dotfiles.git|kulesh/dotfiles" ]
    lib parse_github_repo "git@github.com:kulesh/dotfiles"
    [ "$status" -eq 0 ]
    [[ "$output" == *"|kulesh/dotfiles" ]]
}

@test "parse_github_repo: repo names with hyphens and dots" {
    lib parse_github_repo "user/my-cool.repo"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:user/my-cool.repo.git|user/my-cool.repo" ]
}

@test "parse_github_repo: user/repo.git means the repo, not repo.git" {
    lib parse_github_repo "kulesh/dotfiles.git"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:kulesh/dotfiles.git|kulesh/dotfiles" ]
}

@test "parse_github_repo: rejects anything else" {
    for bad in "not-a-url" "" "just-a-user" "a/b/c" "https://github.com/a/b/c" "https://gitlab.com/a/b"; do
        lib parse_github_repo "$bad"
        [ "$status" -eq 1 ]
    done
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
# Agent docs: AGENTS.md from a shared header plus the template's part
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

@test "write_agent_docs: every template gets AGENTS.md alone, with placeholders filled" {
    for template in base python fastapi ruby rails rust typescript convex; do
        local tmp=$(scratch)
        lib write_agent_docs "$tmp" "$template" "test-project"
        [ "$status" -eq 0 ]
        [ -f "$tmp/AGENTS.md" ]
        [ ! -e "$tmp/CLAUDE.md" ]
        grep -q "Assistant's Role" "$tmp/AGENTS.md"
        [ -z "$(grep '<project-name>' "$tmp/AGENTS.md")" ]
    done
}

@test "write_agent_docs: every project tells its agents keys come from the Keychain, not .env" {
    for template in base python fastapi ruby rails rust typescript convex; do
        local tmp=$(scratch)
        lib write_agent_docs "$tmp" "$template" "test-project"
        grep -q "secret get" "$tmp/AGENTS.md"
        # run, not !: a negated command never fails a bats test under set -e.
        run grep -q "e.g. API keys" "$tmp/AGENTS.md"
        [ "$status" -ne 0 ]
        run grep -q "Use \`.env\` file for local development" "$tmp/AGENTS.md"
        [ "$status" -ne 0 ]
    done
}

# =============================================================================
# copy_template_files (mkproject/_shared/template_helpers.sh)
# =============================================================================

@test "copy_template_files copies a template's files into the project, hidden ones too" {
    local project=$(scratch)
    run zsh -c 'cd "$1" && source "$2" && copy_template_files fastapi' _ "$project" \
        "$DOTFILES_ROOT/mise/.config/mise/tasks/mkproject/_shared/template_helpers.sh"
    [ "$status" -eq 0 ]
    [ -f "$project/.env.example" ]
}

@test "module_name: a project name as a Ruby or Swift module, MyGem" {
    run zsh -c 'source "$1"; module_name my-gem; module_name my_gem; module_name tool' _ "$HELPERS"
    [ "$status" -eq 0 ]
    [ "$output" = $'MyGem\nMyGem\nTool' ]
}
