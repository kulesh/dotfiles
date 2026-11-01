# ADR-011: Project Commands Are mise Tasks

**Status:** Accepted
**Date:** 2026-11-01

## Context

The project commands (`mkproject`, `cloneproject`, `workon`, `lsprojects`, `showproject`, `updateproject`, `rmproject`, `cdproject`, `list_project_types`) were zsh functions in `lib/`: about 1,550 lines, sourced into every shell. Each parsed its own arguments, printed its own usage, and had hand-written zsh completion, or none. The project templates were already mise tasks (`mkproject:python`).

mise tasks get argument parsing, `--help` and shell completion from a usage spec in their header. mise's own zsh completion resolves aliases and asks mise for candidates, including from a command (`complete "name" run="..."`), with no extra tools.

## Decision

Every project command is a global task in `~/.config/mise/tasks/project/` (linked from `mise/.config/mise/tasks/project/`), with an alias in `[shell_alias]` of the global config.

| Command | Task | Moves the shell |
|---|---|---|
| `mkproject <name> [template] [-n]` | `project:new` | to the new project |
| `cloneproject <user/repo or URL>` | `project:clone` | to the clone |
| `workon <name> [-s]` | `project:workon` | to the project |
| `cdproject` | `project:root` | to the project root |
| `rmproject <name> [--delete]` | `project:remove` | to `~/dev`, if you were inside it |
| `lsprojects [--type] [--tools]`, `showproject`, `updateproject [name]`, `list_project_types` | `project:list`, `show`, `update`, `types` | no |

Three mechanisms make tasks fit where functions used to:

- **Following.** A task is a child process and can't change the shell's directory. It writes the destination to `$DOTFILES_FOLLOW`, a file per shell. `lib/follow.zsh` reads it in a `precmd` hook and `cd`s before the next prompt. Without an interactive shell, the task prints `cd <dir>` instead. Bootstrap's clone loop sets `DOTFILES_FOLLOW=/dev/null`.
- **`mise -C /`.** `mise run` loads the current directory's config and records trust for any config it loads. The aliases run from `/`, so running `lsprojects` inside a stranger's repository neither loads nor trusts its config.
- **`--from "$PWD"`.** The commands that act on "the project you're in" receive the caller's directory as a hidden flag. A `VAR=value` prefix on the alias was tried first, and it broke mise's completion.

The sandbox stays in zsh (`lib/sandbox.sh`), and [ADR-003](003-chpwd-over-mise-hooks.md) stands. Entering a sandbox spawns a shell inside yours at the moment you arrive, which `chpwd` does and mise's prompt-time hooks don't. Following uses that: `workon` moves the shell, and the move triggers `chpwd`.

## Consequences

- `<command> --help` works for every command, and Tab completes project names, template names and flags.
- 416 lines of tasks, helpers and `follow.zsh` replace about 1,550 lines of shell functions; `lib/` keeps only what has to run inside the shell.
- Each command starts a `mise run` (tens of milliseconds) instead of calling a function.
- The aliases exist only in shells where mise is activated. Scripts call the tasks directly: `mise -C / run project:clone kulesh/foo`.
- `cloneproject user/repo` replaces `cloneproject gh user/repo`; the old form still works.
- mise treats every file in a tasks directory as a task, so helper files (`project/_lib.zsh`, `mkproject/_shared/template_helpers.sh`) carry `#MISE hide=true`.
