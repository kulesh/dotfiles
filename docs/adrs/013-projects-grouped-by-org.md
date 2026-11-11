# ADR-013: Projects grouped by org

**Status:** Accepted
**Date:** 2026-11-05

## Context

Every project lived directly in `~/dev`. With a work laptop that holds a company's repos next to personal ones and a few third-party clones, that flat list mixed three kinds of project and offered no place for what a group of repos shares: tools, environment and keys.

## Decision

A project is `~/dev/<org>/<repo>`. The org is the GitHub owner: a cloned repo goes under its owner (lowercased, since GitHub owners are case-insensitive), a created one under your GitHub login (from gh's own config, offline), or under the org you name with `mkproject org/name`. The path mirrors the GitHub URL, as in ghq.

```
~/dev/
├── .mise.toml                tools for every project
├── .archive/<org>/<repo>     removed projects
├── kulesh/                   a plain folder
│   ├── actuator/
│   └── waypoints/
└── carrumhealth/
    ├── mise.toml             + [env] and [tools] for every carrumhealth repo
    └── care-service-api/
```

- **An org directory is a plain folder.** Nothing writes into it. A `mise.toml` you put there is inherited by all its repos, as mise loads config from parent directories: tools, `[env]`, and keys named with `secret get` (ADR-012), which bootstrap reports at either level.
- **An org is a directory of projects that isn't a repo itself** (no `.git` of its own), whatever config it holds; `migrate` and bootstrap share that rule (`is_org`, `flat_projects` in `_lib.zsh`). A repo whose packages have their own configs stays one project.
- **Names are `org/repo`.** A bare repo name works while only one org has it; otherwise the command lists the candidates. Tab completes the shortest unambiguous names; the picker shows `org/repo`.
- **The project you're in** is `~/dev/<org>/<repo>` for any directory inside it, even one with its own mise config (a package of the repo). `~/dev`, an org and `~` are never projects.
- **Migration** is a one-time `mise -C / run project:migrate` (`--dry-run` first): each flat project moves under its origin's owner, local ones under your login. It moves everything into `~/dev/.migrating` first, so a repo named like its owner (`~/dev/kulesh` → `~/dev/kulesh/kulesh`) is out of the way before the org directory is made.

## Monorepo mode, tried and dropped (2026-11-11)

The first version made every org a mise monorepo: the project commands wrote `~/dev/<org>/mise.toml` with `monorepo_root = true` and `config_roots = ["*"]`, for `mise run '//...:task'` across an org's repos. It was dropped. An org is a folder of independent repos with their own CI, not one repository, so tasks across all of them were rarely wanted; org-wide `[env]` and `[tools]` never needed it. Against that: the feature is experimental and had already renamed its settings once, a monorepo root extends trust to every config below it, and `migrate` relied on the generated file as its marker for an org, which a `.mise.toml` written into an org by hand confused. Bootstrap removes the generated file where it's unedited.

## Consequences

- Paths change once: editors' recent lists, zoxide entries and Claude Code's per-project history (keyed by path) start fresh for migrated projects
- One-repo orgs appear for third-party clones (`~/dev/crmne/ruby_llm`); the path always says where a repo came from
- The sandbox, trust (`~/dev` and below) and `follow` are unaffected
- A per-org git identity (`includeIf "gitdir:~/dev/<org>/"`) fits this layout; it's left for a separate change
