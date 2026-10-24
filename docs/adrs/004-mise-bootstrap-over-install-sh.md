# ADR-004: Mise Bootstrap Replaces install.sh and Brewfile

**Status:** Accepted
**Date:** 2026-10-17 (revised 2026-10-24 after fresh-machine testing)

## Context

The dotfiles system was built on three pillars: Homebrew (packages), GNU Stow (symlinks), and mise (dev environments). A hand-written `install.sh` (245 lines) glued them together: installing Homebrew, running `brew bundle`, stowing each package, generating SSH keys, and configuring macOS.

Mise v2026.7.4 graduated `mise bootstrap` from experimental. It handles system packages, Homebrew taps, the login shell, and a bootstrap task, declaratively.

## Decision

Replace `install.sh` and `brew/Brewfile` with a minimal bootloader (`mise.sh`) plus `mise bootstrap`. Keep GNU Stow for dotfile symlinks.

```
mise.sh                     installs what mise can't install itself
  Xcode CLI tools           git, compiler (waits for the GUI installer)
  Homebrew                  mise drives brew but can't install it
  mise (via brew)           one copy, upgraded by `mup`
  git clone → ~/.dotfiles
  mise trust && mise bootstrap
                              │
.mise.toml                    ▼
  [bootstrap.packages]      formulae, casks, fonts
  [bootstrap.user]          login shell → zsh
.mise/tasks/bootstrap
  mkdir ~/dev ~/.ssh        real directories, before stow
  stow each package
  mise install              global [tools], now that config is linked
  trust ~/dev, Claude Code, macOS defaults
  GitHub login, clone repos (ADR-005)
```

### Where configuration lives

| File | Contents | Why there |
|------|----------|-----------|
| `.mise.toml` (repo root) | Packages, taps, login shell | Must be readable before stow runs |
| `.mise/tasks/bootstrap` | Stow, tool install, machine setup | Project task; not stowed |
| `mise/.config/mise/config.toml` | Settings, global tools | Runtime config, stowed to `~/.config/mise` |

### Rules learned on a fresh machine

Each of these was a bug found by running on a new Mac:

- **Create `~/dev` and `~/.ssh` before stowing.** Stow links a whole directory into the repo when the target doesn't exist. `~/dev` became a link into `~/.dotfiles`, so projects would land in the checkout; `~/.ssh` did too, so the SSH key was deleted along with the checkout. Existing machines with an already-linked `~/.ssh` are left alone.
- **Find the repo from the task's own path**, not by assuming `~/.dotfiles`.
- **Fail fast** (`set -euo pipefail`). Without it, a missing `shared_vars.sh` emptied the infrastructure exclusion list and stow linked `lib/`, `docs/` and `tests/` into `$HOME`.
- **Run `mise install` after stow.** mise resolves tools before the task runs, when the global config isn't linked yet.
- **Bootstrap with `bash <(curl …)`, not `curl … | bash`.** A pipe takes stdin away from the terminal, and the Homebrew installer can't prompt for sudo.

### Rejected alternatives

- **`mise bootstrap --from <repo>`** clones to `~/.local/share/mise/bootstrap-repo`; stow's symlinks need a stable checkout at `~/.dotfiles`.
- **mise `[dotfiles]` instead of Stow**: explicit per-file declarations versus Stow's zero-config convention.
- **`MISE_GLOBAL_CONFIG_FILE` or pre-linking `~/.config/mise`** to reach bootstrap config before stow: moving bootstrap config to the repo root removes the problem instead.

## Testing

`HOME_DIR` (from `include/shared_vars.sh`) redirects where stow links. When it differs from `$HOME`, steps that change the real machine (`mise install`, trust, installers, GitHub, cloning, `defaults write`) are printed instead of run:

```bash
HOME_DIR=$(mktemp -d) mise run bootstrap
```

`tests/bootstrap.bats` runs the real task this way, with one test per bug above. `mise bootstrap --dry-run` previews packages but doesn't execute the task, so it can't exercise stow.

## Consequences

**Positive:**
- One command takes a fresh Mac to a working machine; re-running is safe
- Package changes are one line: `mise bootstrap packages use brew:foo`
- Bootstrap logic is tested without touching `$HOME`

**Negative:**
- Packages now depend on mise; install.sh, Brewfile and Stow used to be independent
- `mise.sh` still installs three prerequisites by hand
- Tap URLs must be listed explicitly in `[bootstrap.brew.taps]`
- `mise bootstrap` is young: v2026.10.17 panicked once mid-run (`INSTALL_STATE_PLUGINS is None`); a re-run completed
