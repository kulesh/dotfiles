# ADR-004: Mise Bootstrap Replaces install.sh and Brewfile

**Status:** Accepted
**Date:** 2026-10-17

## Context

The dotfiles system was built on three pillars: Homebrew (packages), GNU Stow (symlinks), and mise (dev environments). A hand-written `install.sh` (245 lines) glued them together — installing Homebrew, running `brew bundle`, invoking stow for each package, generating SSH keys, and configuring macOS.

Mise v2026.7.4 graduated `mise bootstrap` from experimental. It now handles system packages (`[bootstrap.packages]`), Homebrew taps, shell activation, system files, services, and a bootstrap task — all declaratively in `config.toml`.

## Decision

Replace `install.sh` and `brew/Brewfile` with `mise bootstrap`. Keep GNU Stow for dotfile symlinks.

### What changes

| Before | After |
|--------|-------|
| `install.sh` orchestrates everything | `mise bootstrap` orchestrates everything |
| `brew/Brewfile` declares packages | `[bootstrap.packages]` in `config.toml` |
| `install.sh` installs Homebrew | `mise bootstrap` installs Homebrew if missing |
| `install.sh` runs stow | `[tasks.bootstrap]` runs stow |
| `install.sh` sets macOS defaults | `[tasks.bootstrap]` sets macOS defaults |

### What stays the same

| Component | Why |
|-----------|-----|
| GNU Stow | Convention-based zero-config symlinking beats explicit declarations |
| `lib/` project management | Custom shell logic, not configuration |
| `sandbox/` profiles | macOS sandbox-exec, no mise equivalent |
| Stow package layout | `<tool>/.config/<tool>/` → `~/.config/<tool>/` |

### What's removed

- `install.sh` (replaced by `mise bootstrap`)
- `brew/Brewfile` (absorbed into `[bootstrap.packages]`)

## Fresh Machine Flow

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kulesh/dotfiles/main/mise.sh)
```

This runs `mise.sh`, which installs the three things mise can't install itself (Xcode CLI tools, Homebrew, mise), clones the repo to `~/.dotfiles`, and runs `mise bootstrap`.

Bootstrap config (`[bootstrap.packages]`, `[bootstrap.user]`) lives in `.mise.toml` at the repo root, not in the stowed `mise/.config/mise/config.toml`, because it must be readable before stow has run. `mise bootstrap --from` was tried and rejected: it clones to `~/.local/share/mise/bootstrap-repo`, but stow's symlinks need a stable checkout at `~/.dotfiles`.

## Consequences

**Positive:**
- Single declarative config for the entire machine
- `mise bootstrap` is idempotent and re-runnable (install.sh wasn't)
- Platform filtering built in (`os = "macos"`)
- Day-2 package management: `mise bootstrap packages use brew:foo`
- Removes custom shell bootstrapping code

**Negative:**
- Coupling: install.sh + Brewfile + Stow were independent; now packages depend on mise
- Mise bootstrap is newly GA (v2026.7.4, ~3 months). install.sh was simple and debuggable
- `[bootstrap.packages]` syntax is less expressive than Brewfile (no `mas` with IDs yet to test, no Brewfile-specific options)
- Tap URLs must be declared explicitly in `[bootstrap.brew.taps]`

**Risks:**
- Cask handling (`brew-cask:` prefix) needs macOS validation
- Custom tap formulae (`kulesh/tap/tc`) need end-to-end testing
- Homebrew auto-install on fresh machine needs verification
