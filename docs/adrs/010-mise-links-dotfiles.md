# ADR-010: mise Links the Dotfiles

**Status:** Accepted
**Date:** 2026-10-31
**Supersedes:** [ADR-001](001-stow-over-symlinks.md)

## Context

GNU Stow linked each top-level directory of the repo into `$HOME`. Stow links a whole directory when it doesn't exist yet ("folding"), and that caused a series of problems:

- **SSH keys deleted.** `~/.ssh` folded into the repo put keys inside the checkout, and removing the checkout removed them.
- **Agent state committed.** `~/.claude` and `~/.pi` folded into the repo, so whatever those apps wrote landed in git.
- **Workarounds.** Bootstrap had to create `~/dev`, `~/.ssh` and `~/.local/bin` before stowing, and `chmod` the repo's ssh config because ssh checks the file a link points to.

mise 2026.10 links directory trees natively ("dotfile groups"), with a group per directory exactly like Stow packages. It also adds what Stow lacks: drift status, pruning, conflict checks before writing anything, permissions, copies and merges.

## Decision

`.mise.toml` declares the links; `mise bootstrap` (step 10, before our task) applies them.

```
mise bootstrap
├── step 10, pre-dotfiles hook
│   ├── stop if ~/.ssh or ~/dev resolves into the repo
│   ├── remove GNU Stow's links (Macs set up before this ADR)
│   └── mkdir ~/.ssh, mode 700
├── step 10, dotfiles (.mise.toml)
│   ├── dotfiles.root = {{config_root}}     sources are this checkout, wherever it is
│   ├── dotfile_groups = [12 directories]   linked file by file: directories stay real
│   ├── ~/.config/nvim                      one link for the directory: lazy-lock.json lands in the repo
│   └── ~/.ssh/config                       a marked block in a real file, from ssh/.ssh/config
└── step 19, the bootstrap task: GitHub, signing, Claude Code, clones, secrets
```

- **Explicit list.** The groups are listed by name, replacing Stow's "every directory except `include`, `lib`, `docs`, `tests`, `tmp`". A new package is one more name.
- **Migration is automatic.** On a Mac set up with Stow, `stow --simulate --delete` lists the links Stow made. If there are any, the hook removes them before mise links. Stow ignores mise's absolute links, so the hook is silent once a Mac has moved over. Applying over Stow's links without this step is unsafe: when tested, mise copied the ssh config through Stow's `~/.ssh` link onto itself and deleted it from the repo.
- **Refusals.** If `~/.ssh` or `~/dev` resolves into the repo, the hook stops and explains. Moving keys or projects is a decision for a person.
- **ssh config as a block.** ssh rejects a config others can write, and it checks the file a link points to. A copy fixes that, but tested, mise overwrote local additions to the copy without warning. Tools like OrbStack add an `Include` line to `~/.ssh/config`. So our settings live between marker comments in a real file, and everything outside the markers belongs to the Mac.
- **`~/.ssh` is created by the hook,** not by `[bootstrap.directories]`. That step runs before the hook, so it would reach a linked `~/.ssh` before the hook could explain the problem.
- **`mise run preview` replaces `HOME_DIR`.** It links into a scratch home, with mise's config, state, data and cache directories moved into it too, so a preview's records never mix with the Mac's. It then runs only the `dotfiles` and `task` parts. The bootstrap task prints its machine-level steps whenever `HOME` isn't the account's home (`~$(id -un)`).

## Consequences

- `stow` leaves the package list. Macs that still have it installed use it once, for the migration.
- Every Mac needs mise 2026.10 or later (groups, hooks around `mise dot apply`).
- New files an app creates in a linked directory stay on that Mac, except under `~/.config/nvim`. To add one to the repo, create it there, or capture it with `mise dot add`.
- Lines added to `~/.ssh/config` outside the markers stay on that Mac. Inside the markers, the next apply restores the repo's version; change `ssh/.ssh/config` in the repo instead.
- `mise -C ~/.dotfiles dot status` shows what is linked and what drifted.
