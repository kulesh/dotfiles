#!/usr/bin/env bats
# Tests for lib/git_utils.sh — pure functions with no side effects

load test_helper

# =============================================================================
# parse_github_url
# =============================================================================

@test "parse_github_url: gh user/repo format" {
    run_zsh_fn parse_github_url "gh" "kulesh/dotfiles"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:kulesh/dotfiles.git|dotfiles" ]
}

@test "parse_github_url: HTTPS URL with .git suffix" {
    run_zsh_fn parse_github_url "https://github.com/kulesh/dotfiles.git"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:kulesh/dotfiles.git|dotfiles" ]
}

@test "parse_github_url: HTTPS URL without .git suffix" {
    run_zsh_fn parse_github_url "https://github.com/kulesh/dotfiles"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:kulesh/dotfiles.git|dotfiles" ]
}

@test "parse_github_url: HTTPS URL with trailing slash" {
    run_zsh_fn parse_github_url "https://github.com/kulesh/dotfiles/"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:kulesh/dotfiles.git|dotfiles" ]
}

@test "parse_github_url: SSH URL" {
    run_zsh_fn parse_github_url "git@github.com:kulesh/dotfiles.git"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:kulesh/dotfiles.git|dotfiles" ]
}

@test "parse_github_url: SSH URL without .git suffix" {
    run_zsh_fn parse_github_url "git@github.com:kulesh/dotfiles"
    [ "$status" -eq 0 ]
    [[ "$output" == *"|dotfiles" ]]
}

@test "parse_github_url: rejects invalid URL" {
    run_zsh_fn parse_github_url "not-a-url"
    [ "$status" -eq 1 ]
}

@test "parse_github_url: rejects empty input" {
    run_zsh_fn parse_github_url ""
    [ "$status" -eq 1 ]
}

@test "parse_github_url: gh format rejects missing repo" {
    run_zsh_fn parse_github_url "gh" "just-a-user"
    [ "$status" -eq 1 ]
}

@test "parse_github_url: handles repo names with hyphens" {
    run_zsh_fn parse_github_url "gh" "user/my-cool-repo"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:user/my-cool-repo.git|my-cool-repo" ]
}

# =============================================================================
# find_mise_root
# =============================================================================

@test "find_mise_root: finds .mise.toml in current directory" {
    local tmpdir=$(mktemp -d)
    # Resolve symlinks (macOS /var → /private/var) to match find_mise_root's ${PWD:A}
    local realdir=$(cd "$tmpdir" && pwd -P)
    touch "$tmpdir/.mise.toml"
    run zsh -c "
        source '${DOTFILES_ROOT}/lib/git_utils.sh'
        cd '$tmpdir'
        find_mise_root
    "
    [ "$status" -eq 0 ]
    [ "$output" = "$realdir" ]
    rm -rf "$tmpdir"
}

@test "find_mise_root: finds .mise.toml in parent directory" {
    local tmpdir=$(mktemp -d)
    local realdir=$(cd "$tmpdir" && pwd -P)
    touch "$tmpdir/.mise.toml"
    mkdir -p "$tmpdir/sub/deep"
    run zsh -c "
        source '${DOTFILES_ROOT}/lib/git_utils.sh'
        cd '$tmpdir/sub/deep'
        find_mise_root
    "
    [ "$status" -eq 0 ]
    [ "$output" = "$realdir" ]
    rm -rf "$tmpdir"
}

@test "find_mise_root: returns error when no .mise.toml exists" {
    local tmpdir=$(mktemp -d)
    run zsh -c "
        source '${DOTFILES_ROOT}/lib/git_utils.sh'
        cd '$tmpdir'
        find_mise_root
    "
    [ "$status" -eq 1 ]
    rm -rf "$tmpdir"
}
