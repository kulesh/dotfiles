# ADR-003: Zsh chpwd Hooks over Mise Hooks for Sandbox Entry

**Status:** Accepted  
**Date:** 2025

## Context

Sandbox entry needs to trigger when the user navigates to a sandboxed project. Two hook mechanisms were evaluated:

1. **Mise hooks** (`[hooks] enter = "..."` in `.mise.toml`) — Runs when mise detects a directory change into a project with a `.mise.toml`. Conceptually clean: the project's own config drives behavior.
2. **Zsh chpwd hooks** — Runs on every `cd`. Shell-level, not tool-level.

## Decision

Use zsh `chpwd` hooks for both sandbox entry and exit.

## Rationale

Mise hooks had race conditions and ordering issues:
- Mise's `enter` hook fires *after* mise processes the config, but sandbox-exec needs to spawn a new shell *before* tools are activated in the current shell.
- Marker files were needed to prevent re-entry, creating state management complexity.
- Mise hooks don't fire on initial shell startup (only on directory change), requiring a separate auto-enter block.

Zsh `chpwd` gives direct control over timing:
- `_sandbox_entry_chpwd` fires in the parent (non-sandbox) shell and spawns the sandbox immediately.
- `_sandbox_chpwd` fires inside the sandbox and triggers exit (code 42) when the user leaves the project directory.
- A `_SANDBOX_SPAWNING` guard variable prevents re-entry during the spawn sequence — simpler than marker files.

## Consequences

**Benefits:**
- Single mechanism for entry and exit.
- No marker files or state on disk.
- Works on shell startup (via the auto-enter block at the end of sandbox.sh).

**Tradeoffs:**
- Runs on every `cd`, even for non-sandboxed projects (guard clause is cheap: two file existence checks).
- Couples sandbox behavior to zsh specifically (not portable to bash/fish, but this system is zsh-only).
- Mise hooks are still present as no-ops (`enter = 'true'`) to prevent mise from complaining.
