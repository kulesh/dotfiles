#!/usr/bin/env bats
# The test suite must never touch the home of whoever runs it.

load test_helper

@test "a skipped suite leaves the real home alone (mise not installed)" {
    local home=$(scratch) bats_bin
    bats_bin=$(PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin command -v bats)
    touch "$home/keep-me"
    # No mise on PATH, so every project test skips in setup.
    run env -i PATH=/usr/bin:/bin HOME="$home" "$bats_bin" "$DOTFILES_ROOT/tests/project.bats"
    [[ "$output" == *"skipped: mise not installed"* || "$output" == *"# skip"* ]]
    [ -f "$home/keep-me" ]
}

# zsh reads ~/.zshenv for every script, and ours puts ~/.local/bin first:
# a test that runs a repo task with the real HOME would run the real tools
# there (mise's installer puts mise in it) instead of the test's stubs.
@test "tests that run the repo's tasks never reach tools in your ~/.local/bin" {
    command -v mise >/dev/null || skip "mise not installed"
    local home=$(scratch) bats_bin tool
    bats_bin=$(command -v bats)
    mkdir -p "$home/.local/bin"
    ln -s "$DOTFILES_ROOT/zsh/.zshenv" "$home/.zshenv"
    for tool in mise gh sc_auth lazygit; do
        printf '#!/bin/sh\necho "%s $*" >> "%s/ran-real"\n' "$tool" "$home" > "$home/.local/bin/$tool"
        chmod +x "$home/.local/bin/$tool"
    done
    run env HOME="$home" "$bats_bin" -f "applies another Mac|previews making the auth key|previews GitHub login" \
        "$DOTFILES_ROOT/tests/sync.bats" "$DOTFILES_ROOT/tests/bootstrap.bats"
    [ "$status" -eq 0 ]
    [ ! -e "$home/ran-real" ] || { cat "$home/ran-real"; false; }
}
