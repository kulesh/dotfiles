# ADR-002: macOS sandbox-exec for AI Coding Agents

**Status:** Accepted  
**Date:** 2025

## Context

AI coding agents (Claude Code, Codex, etc.) need broad filesystem and network access to be effective, but unrestricted access risks credential exfiltration, shell config modification, and unintended system changes.

Considered approaches:

1. **Docker containers** — Strong isolation but heavy. Breaks macOS-native tooling (Homebrew paths, Xcode CLI tools). Adds container management overhead.
2. **VMs** — Maximum isolation but impractical for iterative development.
3. **macOS sandbox-exec** — Kernel-level enforcement via Seatbelt profiles. Native, zero overhead, granular file/network control.
4. **Trust and hope** — No isolation. Fastest but riskiest.

## Decision

Use `sandbox-exec` with a project-scoped profile (`default.sb`). The security model:

- **Read broadly, write broadly, deny what escapes** — Agents can read almost everything (needed for language servers, dependency resolution) and write by default. Writes are denied where your Mac would later run the result outside the sandbox (below).
- **Block secrets at read level** — SSH private keys, AWS credentials and browser data are explicitly denied. The Keychain is not: git's credential helper needs it, and a file rule wouldn't stop `security` reaching the Keychain service anyway, so every `secret` value is readable from inside (ADR-008).
- **Allow all outbound network** — Agents need to fetch packages, query APIs, and access documentation.

## Writes that escape the sandbox (2026-11-07)

Reviewing devvm, a VM-per-project sandbox, showed that the profile's `allow file-write*` list never restricted anything: the profile ends in `(allow default)` and had no general write deny, so every path not explicitly denied was writable. A sandboxed agent couldn't read your SSH keys, but it could write files your Mac later runs outside the sandbox: `~/.dotfiles` libraries, tasks and the profile itself, `~/.config/mise` and other configs that run commands, `~/.local/bin`, `~/.zprofile`, `~/Library/LaunchAgents`, and the project's `.git/hooks` and `.git/config`.

The profile stays a deny-list, and now denies that class: every file the host runs later. The agents' settings linked into `~/.dotfiles/claude` and `~/.dotfiles/pi` stay writable, apart from Claude Code's `statusline.sh`, skills and commands, which run or load as code and which `dsync` would carry to other Macs. `tests/sandbox.bats` runs the profile with `sandbox-exec` (macOS only).

Still open, and listed in the profile: Claude Code's `settings.json` (its hooks run on the host, and `/config` needs it writable), `~/.claude/plugins`, and tools installed under `~/.local/share`, mise's included. Closing those takes a boundary the agent's configuration lives outside of, which devvm provides with a Linux VM, a read-only agent store and secrets the VM never holds. devvm doesn't replace this sandbox for everyday work (no Swift or Xcode, four toolchains, no mise config, no Pi), but suits code you don't trust in its toolchains.

## Project scope (2026-11-11)

Within `~/dev` the sandbox writes only to its own project. Other repos, org configs and the shared `~/dev/.mise.toml` are read-only, as are the project's own mise configs, `.git/hooks`, `.git/config` and `.git` itself: mise loads those configs unprompted for repos it trusts (ADR-014), and git runs what its hooks and config name. Change a project's tools outside the sandbox (`mise use`). Only the two agent settings files linked into `~/.dotfiles` stay writable. `~/.zcompdump` and `~/.config/colima` (included by `~/.ssh/config`) join the denied files.

## Implementation

Entry is via zsh `chpwd` hooks (see ADR-003). A `.sandbox` marker file enables sandboxing per-project. `sandbox-exec` spawns a child zsh with environment variables (`IN_SANDBOX`, `SANDBOX_PROJECT`, `SANDBOX_PROJECT_DIR`) that inform the prompt (starship 🔒 indicator) and the exit hook.

## Consequences

**Benefits:**
- Zero-overhead isolation at the kernel level.
- Per-project opt-in via `.sandbox` marker.
- Multiple independent sandbox shells per project (one per terminal tab).
- Transparent to the agent — tools work normally, just with restricted writes.

**Tradeoffs:**
- `sandbox-exec` is undocumented/deprecated by Apple (though still functional as of macOS 15).
- Profile syntax is Scheme-based and poorly documented. Debugging deny rules requires `log stream`.
- Setuid binaries (`ps`, `top`, `sudo`) are blocked by the kernel — use alternatives (`pgrep`, `htop`).
- A stricter "deny-default writes" profile was explored but abandoned — too many tool-specific write paths needed whitelisting, making the profile brittle. The current "allow-default, deny dangerous" approach is the pragmatic choice.
