#!/usr/bin/env bats
# Tests for lib/project.sh — doc generation and placeholder replacement

load test_helper

# =============================================================================
# _mkproject_escape_sed
# =============================================================================

@test "escape_sed: handles ampersands" {
    run zsh -c "
        source '${DOTFILES_ROOT}/lib/project.sh'
        _mkproject_escape_sed 'foo&bar'
    "
    [ "$status" -eq 0 ]
    [ "$output" = 'foo\&bar' ]
}

@test "escape_sed: handles backslashes" {
    run zsh -c "
        source '${DOTFILES_ROOT}/lib/project.sh'
        _mkproject_escape_sed 'foo\\\\bar'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"\\"* ]]
}

@test "escape_sed: passes through normal text" {
    run zsh -c "
        source '${DOTFILES_ROOT}/lib/project.sh'
        _mkproject_escape_sed 'my-project'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "my-project" ]
}

# =============================================================================
# _mkproject_apply_doc_placeholders
# =============================================================================

@test "apply_placeholders: replaces <project-name>" {
    local tmpdir=$(mktemp -d)
    echo "Welcome to <project-name>!" > "$tmpdir/test.md"
    run zsh -c "
        source '${DOTFILES_ROOT}/lib/project.sh'
        _mkproject_apply_doc_placeholders '$tmpdir/test.md' 'my-api'
    "
    [ "$status" -eq 0 ]
    local content=$(cat "$tmpdir/test.md")
    [ "$content" = "Welcome to my-api!" ]
    rm -rf "$tmpdir"
}

@test "apply_placeholders: replaces <module_name> with underscored version" {
    local tmpdir=$(mktemp -d)
    echo "import <module_name>" > "$tmpdir/test.md"
    run zsh -c "
        source '${DOTFILES_ROOT}/lib/project.sh'
        _mkproject_apply_doc_placeholders '$tmpdir/test.md' 'my-cool-api'
    "
    [ "$status" -eq 0 ]
    local content=$(cat "$tmpdir/test.md")
    [ "$content" = "import my_cool_api" ]
    rm -rf "$tmpdir"
}

@test "apply_placeholders: handles missing file gracefully" {
    run zsh -c "
        source '${DOTFILES_ROOT}/lib/project.sh'
        _mkproject_apply_doc_placeholders '/nonexistent/file.md' 'project'
    "
    [ "$status" -eq 0 ]
}

# =============================================================================
# _mkproject_generate_docs
# =============================================================================

@test "generate_docs: creates CLAUDE.md and AGENTS.md for base template" {
    local tmpdir=$(mktemp -d)
    run zsh -c "
        _MISEWRAPPER_DOTFILES_DIR='${DOTFILES_ROOT}'
        source '${DOTFILES_ROOT}/lib/project.sh'
        _mkproject_generate_docs '$tmpdir' 'base' 'test-project'
    "
    [ "$status" -eq 0 ]
    [ -f "$tmpdir/CLAUDE.md" ]
    [ -f "$tmpdir/AGENTS.md" ]
    # Verify header content is present
    grep -q "Assistant's Role" "$tmpdir/CLAUDE.md"
    # Verify placeholders were replaced
    ! grep -q "<project-name>" "$tmpdir/CLAUDE.md"
    rm -rf "$tmpdir"
}

# =============================================================================
# rmproject argument parsing
# =============================================================================

@test "rmproject: parses project name after flags" {
    # rmproject --delete myproject should set project_name="myproject", not "--delete"
    local tmpdir=$(mktemp -d)
    run zsh -c "
        source '${DOTFILES_ROOT}/include/shared_vars.sh'
        _MISEWRAPPER_DOTFILES_DIR='${DOTFILES_ROOT}'
        MISE_PROJECTS_DIR='$tmpdir'
        source '${DOTFILES_ROOT}/lib/git_utils.sh'
        source '${DOTFILES_ROOT}/lib/project.sh'
        # Project doesn't exist, so rmproject should fail with 'not found' for 'myproject'
        rmproject --delete myproject 2>&1
    "
    # Should complain about 'myproject' not found, NOT '--delete' not found
    [[ "$output" == *"myproject"* ]]
    [[ "$output" != *"'--delete' not found"* ]]
    rm -rf "$tmpdir"
}

@test "generate_docs: works for all template types with project content" {
    for template in base python fastapi ruby rails rust typescript convex; do
        local tmpdir=$(mktemp -d)
        run zsh -c "
            _MISEWRAPPER_DOTFILES_DIR='${DOTFILES_ROOT}'
            source '${DOTFILES_ROOT}/lib/project.sh'
            _mkproject_generate_docs '$tmpdir' '$template' 'test-project'
        "
        [ "$status" -eq 0 ]
        [ -f "$tmpdir/CLAUDE.md" ]
        [ -f "$tmpdir/AGENTS.md" ]
        rm -rf "$tmpdir"
    done
}

# cloneproject against local bare repos, via url.insteadOf for github.com
setup_clone() {
    CLONE_ROOT=$(mktemp -d)
    git -c init.defaultBranch=trunk init -q "$CLONE_ROOT/seed"
    git -C "$CLONE_ROOT/seed" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    mkdir -p "$CLONE_ROOT/remote" "$CLONE_ROOT/dev" "$CLONE_ROOT/bin"
    git clone -q --bare "$CLONE_ROOT/seed" "$CLONE_ROOT/remote/alpha.git"
    printf '[url "%s/remote/"]\n\tinsteadOf = git@github.com:kulesh/\n' "$CLONE_ROOT" > "$CLONE_ROOT/gitconfig"
    printf '#!/bin/sh\necho "mise $*" >> "%s/mise-calls"\n' "$CLONE_ROOT" > "$CLONE_ROOT/bin/mise"
    chmod +x "$CLONE_ROOT/bin/mise"
}

run_cloneproject() {
    GIT_CONFIG_GLOBAL="$CLONE_ROOT/gitconfig" PATH="$CLONE_ROOT/bin:$PATH" run zsh -c "
        source '${DOTFILES_ROOT}/lib/misewrapper.sh'
        MISE_PROJECTS_DIR='$CLONE_ROOT/dev'
        cloneproject gh '$1'"
}

@test "cloneproject: clones a repo whose default branch isn't main or master" {
    setup_clone
    run_cloneproject kulesh/alpha
    [ "$status" -eq 0 ]
    [ "$(git -C "$CLONE_ROOT/dev/alpha" branch --show-current)" = "trunk" ]
    [ -f "$CLONE_ROOT/dev/alpha/.mise.toml" ]
    rm -rf "$CLONE_ROOT"
}

@test "cloneproject: a failed clone reports git's error and leaves nothing behind" {
    setup_clone
    run_cloneproject kulesh/missing
    [ "$status" -ne 0 ]
    [[ "$output" == *"Could not read from remote repository"* || "$output" == *"does not appear to be a git repository"* ]]
    [ ! -e "$CLONE_ROOT/dev/missing" ]
    rm -rf "$CLONE_ROOT"
}

@test "cloneproject: leaves trust to the ~/dev path rule instead of recording it" {
    setup_clone
    run_cloneproject kulesh/alpha
    [ "$status" -eq 0 ]
    [ -z "$(grep trust "$CLONE_ROOT/mise-calls" 2>/dev/null)" ]
    rm -rf "$CLONE_ROOT"
}
