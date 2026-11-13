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
- **Position decides.** A directory directly in `~/dev` is an org, one inside an org is a repo, whatever config or `.git` either holds. A repo whose packages have their own configs stays one project; an org folder kept under git for its notes stays an org.
- **Names are `org/repo`.** A bare repo name works while only one org has it; otherwise the command lists the candidates. Tab completes the shortest unambiguous names; the picker shows `org/repo`.
- **An org is updated as a whole** with `updateproject <org>/`, or `updateproject` in the org folder: every repo is fetched, one table says what each will do, one question, then fast-forwards only. A repo with uncommitted changes, no upstream, or history of its own is listed with the reason and left alone. The org is still a folder of independent repos, not a monorepo; this is the one-project command applied to each.
- **The project you're in** is `~/dev/<org>/<repo>` for any directory inside it, even one with its own mise config (a package of the repo). `~/dev`, an org and `~` are never projects.
- **Migration** from the flat `~/dev/<repo>` was a one-time `project:migrate`: each project moved under its origin's owner, local ones under your login, staged through `~/dev/.migrating` so a repo named like its owner (`~/dev/kulesh` → `~/dev/kulesh/kulesh`) was out of the way first. Telling a leftover flat repo from an org needed a guess (`is_org`), and that guess once took an org folder under git for a repo. Once every Mac had migrated (2026-11-13), the command, the guess and bootstrap's reminder were removed.

## Monorepo mode, tried and dropped (2026-11-11)

The first version made every org a mise monorepo: the project commands wrote `~/dev/<org>/mise.toml` with `monorepo_root = true` and `config_roots = ["*"]`, for `mise run '//...:task'` across an org's repos. It was dropped. An org is a folder of independent repos with their own CI, not one repository, so tasks across all of them were rarely wanted; org-wide `[env]` and `[tools]` never needed it. Against that: the feature is experimental and had already renamed its settings once, a monorepo root extends trust to every config below it, and `migrate` relied on the generated file as its marker for an org, which a `.mise.toml` written into an org by hand confused. Bootstrap removed the generated file where it was unedited, until every Mac had run it (2026-11-13).

## Consequences

- Paths change once: editors' recent lists, zoxide entries and Claude Code's per-project history (keyed by path) start fresh for migrated projects
- One-repo orgs appear for third-party clones (`~/dev/crmne/ruby_llm`); the path always says where a repo came from
- The sandbox and `follow` are unaffected; trust narrowed later to your own orgs ([ADR-014](014-trust-only-your-own-repos.md))
- A per-org git identity (`includeIf "gitdir:~/dev/<org>/"`) fits this layout; it's left for a separate change
