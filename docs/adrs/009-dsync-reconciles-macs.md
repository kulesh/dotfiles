# ADR-009: One Command Reconciles a Mac with the Others

**Status:** Accepted
**Date:** 2026-10-28

## Context

Every Mac has its own checkout of `~/.dotfiles`, and the checkouts drift apart without anyone editing them by hand. Stow links tool configs into the repo, so tools write their state straight into the checkout: `lazy-lock.json` on `:Lazy update`, agent settings, `.mise.toml` on `packages use`. Each Mac then commits on its own schedule, and the next `git pull` reports diverged branches. Recovering takes a sequence of git commands (stash, pull with rebase, resolve, continue, push) that is easy to get wrong when you only need it every few weeks. After that, `mise bootstrap` has to run again before the changes take effect.

## Decision

`dsync` (alias for `mise -C ~/.dotfiles run sync`, task `.mise/tasks/sync`) does the whole thing in order:

```
local changes? ── ask ──▶ commit "<host>: update <files>"   (no: autostash, keep them local)
      │
git pull --rebase --autostash
      │
conflict? ──▶ list files ─▶ lazygit ─▶ resolved? continue the rebase : pause, exit 1
      │                                 aborted?  stop, push nothing
      ▼
ahead of GitHub? ──▶ git push
      │
new commits came in? ──▶ show them, mise bootstrap
```

- **Commit, don't stash, by default.** A change on one Mac is either shared or deliberately kept local. A stash left behind is divergence nobody sees.
- **Conflicts go to a human, in lazygit.** It's already installed, and it shows both sides, resolves, continues or aborts without anyone having to remember git commands. Re-running `dsync` picks up a paused rebase. If no conflicts remain it continues the rebase itself, so resolving by hand needs only `git add`.
- **Bootstrap runs only when something came in.** Local changes are already live on this Mac.
- **A nudge, not automation.** On interactive shell start, `.zshrc` prints `dotfiles: 2 from other Macs, 1 changed here. Run dsync.` It reads the last fetch, which is refreshed in the background at most once a day, so starting a shell never waits on the network.

Two git defaults support this. `pushInsteadOf` pushes HTTPS GitHub clones over SSH, because `mise.sh` clones the dotfiles over HTTPS before there is a GitHub login. `rebase.autoStash` gives a manual `git pull` the same behavior as `dsync`.

## Rejected alternatives

- **Scheduled sync (launchd):** it commits half-finished edits, and its conflicts happen when nobody's there to resolve them.
- **chezmoi or yadm:** both replace Stow to solve a problem that's about git workflow, not linking.
- **Autostash only:** the pull succeeds, but the local changes never reach the other Macs, so the divergence stays.
- **Auto-resolving conflicts (ours/theirs):** it's right for `lazy-lock.json` and silently wrong for real config.

## Consequences

- The dotfiles repo history now includes machine-generated commits named after the Mac, such as `shadow: update lazy-lock.json`
- A conflict pauses the sync with an explanation and leaves the repo mid-rebase; `dsync` resumes it
- `dsync` runs `mise bootstrap`, so it can also clone repos created since the last run
