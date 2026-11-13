#!/usr/bin/env bash
# test_helper.bash — Common setup for bats tests
#
# Loads the shell library modules in a bash-compatible way.
# Since our libraries are zsh, we test the pure-logic functions
# by sourcing them in a zsh subprocess.

# Path to the dotfiles root
export DOTFILES_ROOT="${BATS_TEST_DIRNAME}/.."

# Your shell exports where your projects live; a test that inherited it
# would make and move projects in your real ~/dev.
unset PROJECT_DIR

# A fresh directory for this test. It lives in $BATS_TEST_TMPDIR, which bats
# removes after the test, skipped or not, so tests never delete anything
# themselves: no cleanup can point at the wrong directory.
scratch() {
    mktemp -d "$BATS_TEST_TMPDIR/XXXXXX"
}
