# ADR-012: Projects name the secrets they use

**Status:** Accepted (supersedes the delivery and `include/secrets` parts of ADR-008)
**Date:** 2026-11-01

## Context

ADR-008 moved API keys into the Keychain but kept their delivery: `~/dev/.mise.toml` exported every stored secret into every project under `~/dev`. `include/secrets` listed the names every Mac should have, and its only entry was `ANTHROPIC_API_KEY`.

Two things changed:

- **Nothing in the dotfiles reads the key any more.** Its consumer, CodeCompanion in nvim, is gone. The coding agents (Claude Code, Codex, Gemini CLI, Pi) log in with subscriptions and keep their own credentials.
- **A key in every project is harmful, not just unneeded.** Claude Code prefers `ANTHROPIC_API_KEY` over the subscription login: it asks once in interactive use, and headless runs (`claude -p`) bill the API without asking. Exporting the key into all of `~/dev` would move every scripted agent run there onto API billing.

Keys are for code that calls model APIs directly, such as actuator, recurgent and waypoints. Those projects need specific keys; the rest need none.

## Decision

A project names each secret it uses in its own `.mise.toml`, and mise reads it from the Keychain when the project's environment loads:

```toml
[env]
ANTHROPIC_API_KEY = "{{ exec(command='secret get ANTHROPIC_API_KEY') }}"
```

```
~/dev/.mise.toml          tools for every project; no secrets
~/dev/actuator/.mise.toml ANTHROPIC_API_KEY = exec(secret get ...)  ──► Keychain
~/dev/site/.mise.toml     nothing                                    (no keys)
```

- **The lines are the list.** Bootstrap finds `secret get NAME` in `~/dev/*/.mise.toml` and reports any name this Mac's Keychain lacks. `include/secrets` goes.
- **`~/dev` exports nothing.** `.secrets.sh` and `secret env` go.
- **Storage is unchanged:** `secret set/get/rm/ls/import`, the login Keychain, service `dotfiles`.

## Consequences

- A project's config says which keys it uses; `grep -r 'secret get' ~/dev` answers "who uses this key"
- Agents and scripts in projects that name no keys can't pick one up from the environment
- A key this Mac doesn't have is empty in the project: `secret get` prints nothing for it (and still fails if the Keychain itself does). It used to fail the whole environment, the project's other keys and its tools with it, at every prompt. Bootstrap, and so `dsync`, lists such names (`secret ls`, names only)
- The lines name a key, never a value, so they can be committed
- Within a project that names a key, every process still sees it, agents included. Narrowing a key to one task (fnox, phase 5 of the mise-native plan) remains possible; it isn't needed yet
