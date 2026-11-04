#!/usr/bin/env bats
# Acceptance tests for mise.sh, the bootloader, on a stand-in Mac: uname,
# xcode-select, Homebrew (under $HOMEBREW_PREFIX) and mise are stubs that
# record their calls, in a scratch home that already has the checkout.

load test_helper

setup() {
    # Without the seam, mise.sh would run the real Homebrew in /opt/homebrew.
    grep -q 'HOMEBREW_PREFIX' "$DOTFILES_ROOT/mise.sh" || skip "mise.sh ignores HOMEBREW_PREFIX"
    export HOME=$(scratch)
    mkdir "$HOME/.dotfiles"
    STUBS=$(scratch)
    export HOMEBREW_PREFIX=$(scratch)
    export CALLS=$HOME/calls
    mkdir "$HOMEBREW_PREFIX/bin"
    stub uname 'case $1 in -m) echo arm64 ;; *) echo Darwin ;; esac'
    stub xcode-select 'exit 0'
    # brew list --formula mise succeeds when $BREW_HAS_MISE is set.
    # brew install mise puts a mise stub on PATH, as Homebrew would.
    cat > "$HOMEBREW_PREFIX/bin/brew" <<EOF
#!/bin/sh
echo "brew \$*" >> "$CALLS"
case "\$*" in
    shellenv) ;;
    "list --formula mise") [ -n "\$BREW_HAS_MISE" ] ;;
    "install mise") printf '#!/bin/sh\necho "mise \$*" >> "$CALLS"\n' > "$STUBS/mise"; chmod +x "$STUBS/mise" ;;
esac
EOF
    chmod +x "$HOMEBREW_PREFIX/bin/brew"
}

stub() {   # stub <command> <shell body>
    printf '#!/bin/sh\n%s\n' "$2" > "$STUBS/$1"
    chmod +x "$STUBS/$1"
}

mise_stub() { stub mise 'echo "mise $*" >> "$CALLS"'; }

bootload() {
    PATH="$STUBS:/usr/bin:/bin" run bash "$DOTFILES_ROOT/mise.sh"
}

@test "a Mac without mise gets it from Homebrew, then hands off to mise bootstrap" {
    bootload
    [ "$status" -eq 0 ]
    grep -qx "brew install mise" "$CALLS"
    grep -qx "mise bootstrap" "$CALLS"
}

# An older mise misreads the config (.mise.toml sets min_version), so a
# Homebrew mise that's already here is brought up to date first.
@test "a Homebrew mise that's already installed is upgraded before bootstrap" {
    mise_stub
    BREW_HAS_MISE=1 bootload
    [ "$status" -eq 0 ]
    grep -qx "brew upgrade mise" "$CALLS"
    ! grep -q "brew install mise" "$CALLS"
    [ "$(grep -n 'brew upgrade mise' "$CALLS" | cut -d: -f1)" -lt "$(grep -n 'mise bootstrap' "$CALLS" | cut -d: -f1)" ]
}

@test "a mise installed some other way is left to its own updater" {
    mise_stub
    bootload
    [ "$status" -eq 0 ]
    ! grep -q "brew install mise\|brew upgrade mise" "$CALLS"
    grep -qx "mise bootstrap" "$CALLS"
}
