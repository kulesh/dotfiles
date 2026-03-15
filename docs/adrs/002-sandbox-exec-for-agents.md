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

- **Read broadly, write narrowly** — Agents can read almost everything (needed for language servers, dependency resolution) but can only write to the project directory and tool state directories.
- **Block secrets at read level** — SSH private keys, AWS credentials, browser data, and keychains are explicitly denied.
- **Allow all outbound network** — Agents need to fetch packages, query APIs, and access documentation.

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
