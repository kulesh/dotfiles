#!/usr/bin/env bats
# Acceptance tests for bin/.local/bin/secret, against a stand-in for the
# macOS `security` command (tests/fixtures/security) that prints real
# dump-keychain output.

load test_helper

setup() {
    export KC_STORE=$(scratch)
    export PATH="$DOTFILES_ROOT/tests/fixtures:$PATH"
    SECRET="$DOTFILES_ROOT/bin/.local/bin/secret"
}


@test "set reads the value from the prompt, get returns it" {
    run sh -c "printf 'sk-123\n' | '$SECRET' set OPENAI_API_KEY"
    [ "$status" -eq 0 ]
    run "$SECRET" get OPENAI_API_KEY
    [ "$output" = "sk-123" ]
}

@test "rejects names that aren't environment variable names" {
    run "$SECRET" set lowercase
    [ "$status" -ne 0 ]
    [[ "$output" == *"isn't a valid variable name"* ]]
}

@test "import stores every entry of a JSON object" {
    printf '{"OPENAI_API_KEY": "sk-1", "GEMINI_API_KEY": "g-2"}' > "$KC_STORE/keys.json"
    run "$SECRET" import "$KC_STORE/keys.json"
    [ "$status" -eq 0 ]
    [ "$("$SECRET" get GEMINI_API_KEY)" = "g-2" ]
}

@test "ls lists only this tool's secrets" {
    mkdir -p "$KC_STORE/other-service" && printf x > "$KC_STORE/other-service/NOT_OURS"
    printf 'v\n' | "$SECRET" set ANTHROPIC_API_KEY
    run "$SECRET" ls
    [ "$output" = "ANTHROPIC_API_KEY" ]
}

@test "rm deletes, and get on a missing secret fails" {
    printf 'v\n' | "$SECRET" set GONE_API_KEY
    "$SECRET" rm GONE_API_KEY
    run "$SECRET" get GONE_API_KEY
    [ "$status" -ne 0 ]
}

# =============================================================================
# Delivery: a project names the secrets it uses in its own .mise.toml
# =============================================================================

@test "a project gets exactly the secrets it names, and other projects get none" {
    command -v mise >/dev/null || skip "mise not installed"
    export HOME=$(scratch)
    export PATH="$DOTFILES_ROOT/bin/.local/bin:$PATH"
    export MISE_CONFIG_DIR=$HOME/.config/mise MISE_STATE_DIR=$HOME/.state
    export MISE_DATA_DIR=$HOME/.data MISE_CACHE_DIR=$HOME/.cache
    export MISE_OFFLINE=1 MISE_AUTO_INSTALL=0 MISE_TRUSTED_CONFIG_PATHS=$HOME/dev
    printf 'anthropic-key\n' | secret set ANTHROPIC_API_KEY
    printf 'openai-key\n' | secret set OPENAI_API_KEY
    mkdir -p "$HOME/dev/agent" "$HOME/dev/site"
    # ~/dev's shared files, linked as bootstrap links them.
    local file
    for file in "$DOTFILES_ROOT"/dev/dev/.[!.]*; do ln -s "$file" "$HOME/dev/"; done
    mkdir -p "$HOME/.local/bin"
    ln -s "$DOTFILES_ROOT/bin/.local/bin/secret" "$HOME/.local/bin/secret"
    cat > "$HOME/dev/agent/.mise.toml" <<'EOF'
[env]
ANTHROPIC_API_KEY = "{{ exec(command='secret get ANTHROPIC_API_KEY') }}"
EOF
    : > "$HOME/dev/site/.mise.toml"

    run mise -C "$HOME/dev/agent" env -s bash
    [ "$status" -eq 0 ]
    [[ "$output" == *"ANTHROPIC_API_KEY=anthropic-key"* ]]
    [[ "$output" != *"OPENAI_API_KEY"* ]]

    run mise -C "$HOME/dev/site" env -s bash
    [ "$status" -eq 0 ]
    [[ "$output" != *"_API_KEY"* ]]
}
