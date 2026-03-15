#!/usr/bin/env bash
# test_helper.bash — Common setup for bats tests
#
# Loads the shell library modules in a bash-compatible way.
# Since our libraries are zsh, we test the pure-logic functions
# by sourcing them in a zsh subprocess.

# Path to the dotfiles root
export DOTFILES_ROOT="${BATS_TEST_DIRNAME}/.."

# Run a zsh function from our library and capture output.
# Usage: run_zsh_fn <function_name> [args...]
run_zsh_fn() {
    local fn_name="$1"
    shift
    run zsh -c "
        source '${DOTFILES_ROOT}/include/shared_vars.sh'
        _MISEWRAPPER_DOTFILES_DIR='${DOTFILES_ROOT}'
        MISE_PROJECTS_DIR='\${PROJECT_DIR}'
        source '${DOTFILES_ROOT}/lib/git_utils.sh'
        ${fn_name} \"\$@\"
    " -- "$@"
}
