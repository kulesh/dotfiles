#!/usr/bin/env bats
# Acceptance tests for the interactive shell: zsh/.zshrc loaded the way a new
# terminal loads it, in a scratch home, with stubs for tools it only decorates
# with (fzf, starship, zoxide).

load test_helper

setup() {
    command -v mise >/dev/null || skip "mise not installed"
    command -v zsh >/dev/null || skip "zsh not installed"
    export HOME=$(scratch)
    ln -s "$DOTFILES_ROOT" "$HOME/.dotfiles"
    mkdir "$HOME/stubs"
    for tool in fzf starship zoxide; do
        printf '#!/bin/sh\n' > "$HOME/stubs/$tool"
        chmod +x "$HOME/stubs/$tool"
    done
    export PATH=$HOME/stubs:$PATH
    export MISE_CONFIG_DIR="$DOTFILES_ROOT/mise/.config/mise"
    export MISE_STATE_DIR=$HOME/.state MISE_DATA_DIR=$HOME/.data MISE_CACHE_DIR=$HOME/.cache
    export MISE_OFFLINE=1 MISE_VERSION_CHECK=0 MISE_AUTO_INSTALL=0
}

interactive() {   # interactive <zsh code>: run it in a shell that loaded .zshrc
    run env ZDOTDIR="$DOTFILES_ROOT/zsh" zsh -i -c "$1"
}

# The project commands are aliases for mise tasks. zsh completes an alias as
# the command it expands to, so Tab after workon needs mise's completion,
# which a Homebrew mise installs where /bin/zsh never looks.
@test "the shell completes mise, so the project aliases complete too" {
    interactive 'print -r -- "mise: ${_comps[mise]:-none}"'
    [[ "$output" == *"mise: _mise"* ]]
}
