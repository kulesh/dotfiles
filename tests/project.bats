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
