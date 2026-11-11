#!/usr/bin/env bats
# Claude Code's shared permissions (claude/.claude/settings.json). git runs
# outside Claude's own sandbox (excludedCommands), so what it may run without
# asking matters; and a rule without :* matches only the bare command.

load test_helper

rules() {   # rules <allow|deny|ask>: one per line
    python3 -I -c 'import json, sys; print("\n".join(json.load(open(sys.argv[1]))["permissions"][sys.argv[2]]))' \
        "$DOTFILES_ROOT/claude/.claude/settings.json" "$1"
}

@test "deny and ask rules for commands match their arguments too (:*)" {
    run bash -c "{ $(declare -f rules); rules deny; rules ask; } | grep '^Bash(' | grep -v ':\*)$'"
    [ -z "$output" ]
}

@test "git isn't allowed wholesale: git -c and git config would run anything" {
    run rules allow
    [[ "$output" != *"Bash(git:*)"* ]]
    [[ "$output" == *"Bash(git status:*)"* ]]
    [[ "$output" != *"Bash(git config"* ]]
}

@test "Claude can't edit git hooks or git config, which the next git command would run" {
    run rules deny
    for rule in 'Edit(**/.git/hooks/**)' 'Write(**/.git/hooks/**)' 'Edit(**/.git/config)' 'Write(**/.git/config)'; do
        [[ "$output" == *"$rule"* ]]
    done
}
