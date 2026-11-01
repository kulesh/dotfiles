#!/usr/bin/env bats
# The test suite must never touch the home of whoever runs it.

load test_helper

@test "a skipped suite leaves the real home alone (mise not installed)" {
    local home=$(mktemp -d) bats_bin
    bats_bin=$(PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin command -v bats)
    touch "$home/keep-me"
    # No mise on PATH, so every project test skips in setup; teardown still runs.
    run env -i PATH=/usr/bin:/bin HOME="$home" "$bats_bin" "$DOTFILES_ROOT/tests/project.bats"
    [[ "$output" == *"skipped: mise not installed"* || "$output" == *"# skip"* ]]
    [ -f "$home/keep-me" ]
    rm -rf "$home"
}
