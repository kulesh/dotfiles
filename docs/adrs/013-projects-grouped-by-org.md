# ADR-013: Projects grouped by org, each org a mise monorepo

**Status:** Accepted
**Date:** 2026-11-05

## Context

Every project lived directly in `~/dev`. With a work laptop that holds a company's repos next to personal ones and a few third-party clones, that flat list mixed three kinds of project and offered no place for what a group of repos shares: tools, environment, keys, or running one task across all of them.

## Decision

A project is `~/dev/<org>/<repo>`. The org is the GitHub owner: a cloned repo goes under its owner (lowercased, since GitHub owners are case-insensitive), a created one under your GitHub login (from gh's own config, offline), or under the org you name with `mkproject org/name`. The path mirrors the GitHub URL, as in ghq.

```
~/dev/
├── .mise.toml                tools for every project
├── .archive/<org>/<repo>     removed projects
├── kulesh/
│   ├── mise.toml             monorepo_root = true; [monorepo] config_roots = ["*"]
│   ├── actuator/
│   └── waypoints/
└── carrumhealth/
    ├── mise.toml             + [env] and [tools] for every carrumhealth repo
    └── care-service-api/
```

- **Each org directory is a mise monorepo.** The first project in an org writes its `mise.toml`; an existing one is the org's own and is left alone. `config_roots = ["*"]` includes every repo, so new clones join without editing it. From anywhere in the org, `mise run '//...:test'` runs `test` in every repo and `mise run //<repo>:test` in one.
- **Org config is inherited.** Tools and `[env]` in `~/dev/<org>/mise.toml` reach all of the org's repos, including keys named with `secret get` (ADR-012); bootstrap reports missing ones at either level.
- **Names are `org/repo`.** A bare repo name works while only one org has it; otherwise the command lists the candidates. Tab completes the shortest unambiguous names; the picker shows `org/repo`.
- **The project you're in** is `~/dev/<org>/<repo>` for any directory inside it, even one with its own mise config (a package of the repo). `~/dev`, an org and `~` are never projects.
- **Migration** is a one-time `mise -C / run project:migrate` (`--dry-run` first): each flat project moves under its origin's owner, local ones under your login. It moves everything into `~/dev/.migrating` first, so a repo named like its owner (`~/dev/kulesh` → `~/dev/kulesh/kulesh`) is out of the way before the org directory is made.

## Consequences

- Paths change once: editors' recent lists, zoxide entries and Claude Code's per-project history (keyed by path) start fresh for migrated projects
- One-repo orgs appear for third-party clones (`~/dev/crmne/ruby_llm`); the path always says where a repo came from
- The sandbox, trust (`~/dev` and below) and `follow` are unaffected
- A per-org git identity (`includeIf "gitdir:~/dev/<org>/"`) fits this layout; it's left for a separate change
