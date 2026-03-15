#!/usr/bin/env bats
# Tests for stow package auto-discovery logic in install.sh

load test_helper

# Simulate the discovery logic from install.sh in a temp directory
discover_packages() {
    local test_dir="$1"
    zsh -c "
        source '${DOTFILES_ROOT}/include/shared_vars.sh'
        cd '$test_dir'
        local packages=()
        for dir in */; do
            local dirname=\"\${dir%/}\"
            [[ \"\$dirname\" == .* ]] && continue
            local is_infra=false
            for infra in \"\${_DOTFILES_INFRA[@]}\"; do
                [[ \"\$dirname\" == \"\$infra\" ]] && { is_infra=true; break; }
            done
            \$is_infra && continue
            packages+=(\"\$dirname\")
        done
        echo \"\${packages[*]}\"
    "
}

@test "discovery: includes tool directories" {
    local tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir"/{zsh,git,nvim,ghostty}
    local result=$(discover_packages "$tmpdir")
    [[ "$result" == *"zsh"* ]]
    [[ "$result" == *"git"* ]]
    [[ "$result" == *"nvim"* ]]
    [[ "$result" == *"ghostty"* ]]
    rm -rf "$tmpdir"
}

@test "discovery: excludes infrastructure directories" {
    local tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir"/{zsh,include,lib,docs,tests,tmp}
    local result=$(discover_packages "$tmpdir")
    [[ "$result" == *"zsh"* ]]
    [[ "$result" != *"include"* ]]
    [[ "$result" != *"lib"* ]]
    [[ "$result" != *"docs"* ]]
    [[ "$result" != *"tests"* ]]
    [[ "$result" != *"tmp"* ]]
    rm -rf "$tmpdir"
}

@test "discovery: excludes hidden directories" {
    local tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir"/{zsh,.git,.claude}
    local result=$(discover_packages "$tmpdir")
    [[ "$result" == *"zsh"* ]]
    [[ "$result" != *".git"* ]]
    [[ "$result" != *".claude"* ]]
    rm -rf "$tmpdir"
}

@test "discovery: includes yazi (previously missing from hardcoded list)" {
    local tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir"/{zsh,yazi}
    local result=$(discover_packages "$tmpdir")
    [[ "$result" == *"yazi"* ]]
    rm -rf "$tmpdir"
}

@test "discovery: matches expected packages from real repo" {
    local result=$(discover_packages "$DOTFILES_ROOT")
    # These should all be discovered
    [[ "$result" == *"zsh"* ]]
    [[ "$result" == *"git"* ]]
    [[ "$result" == *"mise"* ]]
    [[ "$result" == *"nvim"* ]]
    [[ "$result" == *"brew"* ]]
    [[ "$result" == *"starship"* ]]
    [[ "$result" == *"yazi"* ]]
    [[ "$result" == *"sandbox"* ]]
    [[ "$result" == *"claude"* ]]
    # These should NOT be discovered
    [[ "$result" != *"include"* ]]
    [[ "$result" != *"lib"* ]]
}
