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
- `_sandbox_chpwd` fires inside the sandbox and exits it when the user leaves the project directory, writing the destination to a file the outer shell made (`$SANDBOX_EXIT_FILE`), which then follows. (Before 2026-11: exit code 42 and a file in `~/.cache/sandbox`, which nothing created.)
- Entry walks up from the directory you arrived in to the project's `.sandbox` marker (written by `workon -s`), so landing in a subdirectory sandboxes the whole project. The sandboxed shell starts where you are; nothing `cd`s during the spawn, so nothing can re-enter. Inside, a `cd` in a subshell is ignored: zsh runs `chpwd` there too.

## Consequences

**Benefits:**
- Single mechanism for entry and exit.
- State on disk is the `.sandbox` marker per project and the exit file for the life of one sandboxed shell; nothing else.
- Works on shell startup (via the auto-enter block at the end of sandbox.sh).

**Tradeoffs:**
- Runs on every `cd`, even for non-sandboxed projects (the walk up is cheap: one file test per directory level).
- Couples sandbox behavior to zsh specifically (not portable to bash/fish, but this system is zsh-only).
- `~/dev/.mise.toml` declares no mise hooks; the no-op `enter`/`leave` it once carried started a process on every `cd` and kept nothing from complaining.
