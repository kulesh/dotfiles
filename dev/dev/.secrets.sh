# Sourced by ~/dev/.mise.toml: exports the secrets stored with `secret set`.
# No values here; they come from the Keychain each time mise loads the env.
command -v security >/dev/null && eval "$("$HOME/.local/bin/secret" env)"
