# ADR-014: mise trusts only your own repos

**Status:** Accepted (replaces the `~/dev` trust of the mise-native plan's phase 1)
**Date:** 2026-11-11

## Context

Phase 1 set `trusted_config_paths = ["~/dev"]` in the shared mise config, so every project's config loaded without a prompt. With ADR-013, third-party repos live in `~/dev/<owner>/` too, and `cloneproject` moves the shell into each new clone. A repo's mise config can run commands (`exec()` in `[env]`, `_.source`, hooks) and install tools, so `cloneproject someone/repo` ran that repo's code at once, before a sandbox could start (mise's directory hook runs ahead of ours). `env_file = '.env'` also let any repo's `.env` set the shell's environment, `PATH` included.

## Decision

mise trusts, without asking, only the shared `~/dev/.mise.toml` and repos owned by you or your GitHub orgs:

```
~/.config/mise/conf.d/trust.toml   written by bootstrap, per Mac
  trusted_config_paths = ["~/dev/.mise.toml", "~/dev/<login>", "~/dev/<org>", ...]
```

- **Per Mac:** the login and orgs differ (`kulesh` here, `kulesh-carrum` and `carrumhealth` on a work laptop), so bootstrap writes the list from `gh` (your login and `gh api user/orgs`) into a file of its own, not the linked `config.toml`.
- **One file, whole list:** mise doesn't combine `trusted_config_paths` from separate files; the last read replaces the rest, so the generated file holds every entry.
- **Fail closed:** without a GitHub login it trusts the shared file alone; a failed lookup leaves the file as it was. The sandbox profile denies writes to `~/.config/mise`, so an agent can't widen it.
- **Anyone else's clone asks:** `mise trust` in that repo, after reading its config.
- **No `env_file`:** a project's `.env` no longer feeds the environment; apps that read `.env` themselves (the fastapi template) are unaffected.

## Consequences

- Third-party clones (`~/dev/crmne/ruby_llm`) show mise's trust error until you trust them
- A new org you join is trusted after the next bootstrap (`dsync` runs it)
- Tests set `MISE_TRUSTED_CONFIG_PATHS` for their scratch `~/dev`
