#!/usr/bin/env bats
# Acceptance tests for bin/.local/bin/secret, against a stand-in for the
# macOS `security` command (tests/fixtures/security) that prints real
# dump-keychain output.

load test_helper

setup() {
    export KC_STORE=$(mktemp -d)
    export PATH="$DOTFILES_ROOT/tests/fixtures:$PATH"
    SECRET="$DOTFILES_ROOT/bin/.local/bin/secret"
}

teardown() { rm -rf "$KC_STORE"; }

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

@test "env output reproduces values exactly when evaluated" {
    printf "it's \$HOME and \"quotes\"\n" | "$SECRET" set TRICKY_API_KEY
    run bash -c "eval \"\$('$SECRET' env)\"; printf '%s' \"\$TRICKY_API_KEY\""
    [ "$output" = "it's \$HOME and \"quotes\"" ]
}

@test "rm deletes, and get on a missing secret fails" {
    printf 'v\n' | "$SECRET" set GONE_API_KEY
    "$SECRET" rm GONE_API_KEY
    run "$SECRET" get GONE_API_KEY
    [ "$status" -ne 0 ]
}
