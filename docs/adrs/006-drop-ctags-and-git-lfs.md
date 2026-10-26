# ADR-006: Drop ctags Hooks and git-lfs

**Status:** Accepted
**Date:** 2026-10-26

## Context

`git/.git_template` installed hooks in every new or cloned repo that rebuilt a ctags index after each commit, checkout, merge and rebase. `.gitconfig` also declared the git-lfs filter as required. Neither tool was in the package list, so on fresh machines the hooks failed silently and LFS repos would have failed to check out. A review found neither was in use:

- **ctags:** nothing reads the tags. Neovim navigates with language servers, and coding agents (Claude Code and others) search with ripgrep and LSP. Tags only match text, and they go stale between hook runs.
- **git-lfs:** the filter block is what `git lfs install` writes; no repo was known to use LFS.

## Decision

Remove both rather than install them: the git template directory and `init.templatedir`, the lfs filter, `.tags` from the global gitignore, and the `git-lfs` and `universal-ctags` packages.

## Consequences

- One fewer background job per git operation, and no git hooks installed by default
- Repos cloned before this change still have the copied hooks in `.git/hooks`; they're inert without ctags and can be removed by hand
- A repo that turns out to use LFS shows pointer files instead of content until git-lfs is installed (`mise bootstrap packages use brew:git-lfs`, then `git lfs install`)
