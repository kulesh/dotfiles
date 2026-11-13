#!/usr/bin/env bash
# test_helper.bash — Common setup for bats tests
#
# Loads the shell library modules in a bash-compatible way.
# Since our libraries are zsh, we test the pure-logic functions
# by sourcing them in a zsh subprocess.

bats_require_minimum_version 1.5.0   # run --separate-stderr

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

# mise with its state, data and cache in <dir>, offline, installing nothing.
isolate_mise() {   # isolate_mise <dir>
    export MISE_STATE_DIR=$1/.state MISE_DATA_DIR=$1/.data MISE_CACHE_DIR=$1/.cache
    export MISE_OFFLINE=1 MISE_VERSION_CHECK=0 MISE_AUTO_INSTALL=0
}

# Run a shell command at a terminal, zsh's own pty, the same on macOS and
# Linux, setting $output and $status as run does. With --answer, the reply
# is typed once the command asks [y/N], as a person would; typing ahead
# was lost by macOS's script(1).
at_terminal() {   # at_terminal [--answer <reply>] <sh command>
    local answer=
    if [ "$1" = --answer ]; then answer=$2; shift 2; fi
    export AT_TERMINAL_COMMAND=$1
    run zsh -c '
        zmodload zsh/zpty
        zpty session '\''sh -c "$AT_TERMINAL_COMMAND"; print -r -- "exit=$?"'\''
        seen=
        if [[ -n $1 ]]; then zpty -r session seen "*\[y/N\]*" && zpty -w session "$1"; fi
        while zpty -r session chunk; do seen+=$chunk; done
        zpty -d session
        print -r -- "${seen%exit=*}"
        code=${${seen##*exit=}%%[^0-9]*}
        exit ${code:-1}
    ' _ "$answer"
}
