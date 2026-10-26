# ADR-008: Secrets in the macOS Keychain

**Status:** Accepted
**Date:** 2026-10-26

## Context

API keys for coding agents and editor plugins lived in plain text in `~/dev/.keys.json`, loaded into every project's environment by `~/dev/.mise.toml` (`_.file`). It was kept out of git only by a `.gitignore` pattern, and it was readable by anything that reads files: backups, `grep`, and coding agents allowed `Read(**)`.

## Decision

Store secrets as generic passwords in the login Keychain, under the service `dotfiles`, one item per environment variable.

- **`secret`** (`bin/.local/bin/secret`, stowed to `~/.local/bin`): `set` prompts for the value so it never appears in argv or shell history; `get`, `rm`, `ls`; `import` for a one-time move from `.keys.json`; `env` prints `export` lines.
- **Delivery is unchanged in scope:** `~/dev/.mise.toml` uses `_.source = .secrets.sh`, which evaluates `secret env`. Variables exist only in projects under `~/dev`, as before.
- **`include/secrets`** lists the names (never values) every machine should have. Keychain items created with `security` are local to the Mac and don't sync, so bootstrap reports any that are missing.

## What this does and doesn't protect

| Threat | Before | After |
|--------|--------|-------|
| Accidental commit, backup, file sharing | Exposed if the ignore pattern missed | Not on disk |
| Reading files (`grep`, `Read(**)` agents) | Exposed | Protected |
| A process running as you calling `security` | — | **Still exposed** |
| Environment of processes under `~/dev` | Exposed | **Still exposed** |

The sandbox profile allows Keychain reads because git's credential helper needs them. Keeping keys from agents entirely would mean giving each key only to the tool that uses it (a wrapper per tool) instead of exporting all of them into `~/dev`.

## Rejected alternatives

- **1Password CLI**: stronger access control, but a paid dependency, and not on every Mac.
- **`age`/sops-encrypted files**: portable and syncable through the repo, but needs its own key management and still decrypts into the environment.
- **Exporting from `.zshrc`**: simpler, but widens the keys' scope from `~/dev` to every shell.

## Consequences

- Each Mac needs its secrets entered once (`secret set NAME`); bootstrap lists what's missing
- `mise` runs `security` for each secret when it loads the `~/dev` environment
- `secret import` passes values as arguments, briefly visible in the process list; it's meant for the one-time migration
