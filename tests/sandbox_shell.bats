#!/usr/bin/env bats
# Acceptance tests for the shell side of workon -s (lib/sandbox.sh): entering
# a sandboxed project, leaving it, and exiting. A stand-in sandbox-exec runs
# the sandboxed shell with a scripted action ($CHILD) instead of zsh -i, so
# these run anywhere; tests/sandbox.bats covers the profile itself on macOS.

load test_helper

setup() {
    export HOME=$(cd "$(scratch)" && pwd -P)
    unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_STATE_HOME IN_SANDBOX
    PROJECT=$HOME/dev/acme/foo
    mkdir -p "$PROJECT" "$HOME/dev/acme/foobar" "$HOME/elsewhere" "$HOME/stubs"
    : > "$PROJECT/.mise.toml"
    : > "$PROJECT/.sandbox"
    mkdir -p "$HOME/.config/sandbox/profiles"
    : > "$HOME/.config/sandbox/profiles/default.sb"
    # sandbox-exec -f P -D .. env VARS... /bin/zsh -i: keep env and its
    # variables, run $CHILD in a zsh that loaded sandbox.sh instead of zsh -i.
    # $SANDBOX_EXEC_FAILS makes it fail the way a bad profile does.
    cat > "$HOME/stubs/sandbox-exec" <<'EOF'
#!/usr/bin/env bash
[ -n "$SANDBOX_EXEC_FAILS" ] && { echo "sandbox-exec: invalid profile" >&2; exit 65; }
printf '%s\n' "$@" > "$HOME/sandbox-exec.args"
while [ "$1" != env ]; do shift; done
args=("$@"); unset 'args[-1]' 'args[-1]'
exec "${args[@]}" /bin/zsh -c 'source "$LIB"; '"$CHILD"
EOF
    chmod +x "$HOME/stubs/sandbox-exec"
    export PATH=$HOME/stubs:$PATH LIB=$DOTFILES_ROOT/lib/sandbox.sh
}

outer_shell() {   # cd into the sandboxed project, then report where it ended up
    run zsh -c 'source "$LIB"; cd "$1"; print -r -- "after=$PWD"' _ "$PROJECT"
}

@test "leaving the project inside the sandbox takes the outer shell where you went" {
    CHILD="cd $HOME/elsewhere" outer_shell
    [ "$status" -eq 0 ]
    [[ "$output" == *"after=$HOME/elsewhere"* ]]
    [ ! -e "$HOME/.cache/sandbox" ]   # nothing left behind
}

@test "a sibling whose name starts like the project's is outside it" {
    CHILD="cd $HOME/dev/acme/foobar" outer_shell
    [[ "$output" == *"after=$HOME/dev/acme/foobar"* ]]
}

@test "exiting the sandboxed shell closes the shell it ran in" {
    CHILD="exit 3" outer_shell
    [[ "$output" != *"after="* ]]
}

@test "a sandbox that can't start leaves the shell open where it was, and says why" {
    SANDBOX_EXEC_FAILS=1 CHILD=true outer_shell
    [[ "$output" == *"invalid profile"* ]]
    [[ "$output" == *"after=$PROJECT"* ]]
}

@test "a missing profile leaves the shell open, and says so" {
    rm "$HOME/.config/sandbox/profiles/default.sb"
    CHILD=true outer_shell
    [[ "$output" == *"profile not found"* ]]
    [[ "$output" == *"after=$PROJECT"* ]]
}

@test "the profile gets the project and the real path of ~/.ssh, whose keys it hides" {
    mkdir -p "$HOME/keys"
    ln -s "$HOME/keys" "$HOME/.ssh"
    CHILD=true outer_shell
    grep -qx "SSH_REAL=$HOME/keys" "$HOME/sandbox-exec.args"
    grep -qx "PROJECT_DIR=$PROJECT" "$HOME/sandbox-exec.args"
    grep -qx "HOME=$HOME" "$HOME/sandbox-exec.args"
}
