# ADR-001: GNU Stow for Dotfile Management

**Status:** Accepted  
**Date:** 2024 (retroactive)

## Context

Dotfiles from a git repo need to be symlinked into `$HOME`. Common approaches:

1. **Manual symlinks** — `ln -s` for each file. Error-prone, tedious to maintain.
2. **Install script with loops** — Script iterates a list and creates symlinks. Better, but still couples the list to the script.
3. **GNU Stow** — Convention-based: directory structure *is* the specification.
4. **Nix/Home Manager** — Declarative but heavyweight; violates the "grokable" tenet.

## Decision

Use GNU Stow. Each top-level directory in the repo is a "package" whose contents mirror the target (`$HOME`). Running `stow <package>` creates the symlinks.

```
ghostty/.config/ghostty/config  →  ~/.config/ghostty/config
zsh/.zshrc                      →  ~/.zshrc
```

## Consequences

**Benefits:**
- Adding a new tool = creating a directory with the right structure. No script changes needed.
- `--adopt` flag handles existing files by pulling them into the repo.
- `--restow` is idempotent — safe to run repeatedly.
- Stow packages are auto-discovered (see Phase 2 refactor), eliminating manual sync.

**Tradeoffs:**
- Stow is an additional dependency (installed via Homebrew early in bootstrap).
- Directory structure can feel verbose for single-file configs (e.g., `brew/Brewfile` creates `~/Brewfile`).
- Stow doesn't handle conditional logic (e.g., different config per machine). We accept this — the system targets macOS only.
