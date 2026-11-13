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
    # Linked into the scratch home as bootstrap links them, so zsh writes its
    # caches (.zcompdump) there and never into the repo.
    ln -s "$DOTFILES_ROOT/zsh/.zshrc" "$DOTFILES_ROOT/zsh/.zshenv" "$HOME/"
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
    run zsh -i -c "$1"
}

# The project commands are aliases for mise tasks. zsh completes an alias as
# the command it expands to, so Tab after workon needs mise's completion,
# which a Homebrew mise installs where /bin/zsh never looks.
@test "the shell completes mise, so the project aliases complete too" {
    interactive 'print -r -- "mise: ${_comps[mise]:-none}"'
    [[ "$output" == *"mise: _mise"* ]]
}

# A shell keeps the config it started with. When a file it loaded changes
# (dsync, git pull, an edit), it reloads itself before the next prompt.
@test "the shell reloads itself before the next prompt once a file it loaded changes" {
    # A copy, so the test can change it without touching the repo.
    rm "$HOME/.zshrc"
    cp "$DOTFILES_ROOT/zsh/.zshrc" "$HOME/.zshrc"
    interactive '
        _dotfiles_reload() { print RELOAD }
        _dotfiles_reload_if_changed; print unchanged
        touch -m -t 209901010000 ~/.zshrc
        _dotfiles_reload_if_changed; _dotfiles_reload_if_changed'
    [[ "$output" == *"unchanged"*"RELOAD"* ]]
    [[ "$output" != *"RELOAD"*"RELOAD"* ]]
}

@test "reloading is a prompt hook, so every open window catches up" {
    interactive 'print -r -- "precmd: ${precmd_functions[*]}"'
    [[ "$output" == *"precmd: "*"_dotfiles_reload_if_changed"* ]]
}

# mise warns at every prompt about a deprecated setting in the global config.
@test "the global mise config uses no setting this mise has deprecated" {
    run mise settings ls
    [ "$status" -eq 0 ]
    [[ "$output" != *"deprecated"* ]]
}

@test "the shell waits to reload while it has jobs, so they aren't orphaned" {
    rm "$HOME/.zshrc"
    cp "$DOTFILES_ROOT/zsh/.zshrc" "$HOME/.zshrc"
    interactive '
        _dotfiles_reload() { print RELOAD }
        sleep 30 &
        touch -m -t 209901010000 ~/.zshrc
        _dotfiles_reload_if_changed
        kill %1; wait 2>/dev/null
        _dotfiles_reload_if_changed'
    [[ "$output" == *"after your jobs finish"* ]]
    [ "$(grep -c RELOAD <<< "$output")" -eq 1 ]
}

@test "PATH has each directory once, however often the shell reloads" {
    interactive 'source ~/.zshenv; source ~/.zshrc; source ~/.zshenv; print -l -- P:${^path}'
    [ -z "$(grep '^P:' <<< "$output" | sort | uniq -d)" ]
}

# DOTFILES is wherever .zshenv really lives, so a checkout outside
# ~/.dotfiles works the same: one variable, resolved, for every user of it.
@test "the shell finds its libraries from a checkout outside ~/.dotfiles" {
    rm "$HOME/.dotfiles"
    interactive 'print -r -- "dotfiles=$DOTFILES"; whence -w _dotfiles_follow _dotfiles_reload_if_changed'
    [[ "$output" == *"dotfiles=$(cd "$DOTFILES_ROOT" && pwd -P)"* ]]
    [[ "$output" == *"_dotfiles_follow: function"* ]]
    [[ "$output" == *"_dotfiles_reload_if_changed: function"* ]]
}

# The project commands are mise tasks, separate processes: they see where
# projects live only if the shell exports it.
@test "the shell exports where projects live to the commands it runs" {
    interactive 'printenv PROJECT_DIR'
    [ "${lines[-1]}" = "$HOME/dev" ]
}

# ssh-agent starts empty after a reboot; git signs through it (ADR-015).
@test "a new shell puts this Mac's enclave keys back in the agent, once" {
    mkdir -p "$HOME/.ssh"
    for role in auth sign; do
        echo handle > "$HOME/.ssh/id_enclave_$role"
        echo "sk-ecdsa-sha2-nistp256@openssh.com AAAA$role ssh-$role-2026-11-13" > "$HOME/.ssh/id_enclave_$role.pub"
    done
    printf '%s\n' '#!/bin/sh' \
        'case $1 in' \
        '-L) cat "$HOME/agent" 2>/dev/null || exit 1 ;;' \
        '-q) echo "$SSH_SK_PROVIDER $2" >> "$HOME/added"; cut -d" " -f1,2 "$2.pub" >> "$HOME/agent" ;;' \
        'esac' > "$HOME/stubs/ssh-add"
    chmod +x "$HOME/stubs/ssh-add"
    interactive 'true'
    [ "$(cat "$HOME/added")" = "/usr/lib/ssh-keychain.dylib $HOME/.ssh/id_enclave_auth
/usr/lib/ssh-keychain.dylib $HOME/.ssh/id_enclave_sign" ]
    interactive 'true'
    [ "$(wc -l < "$HOME/added")" -eq 2 ]
}
