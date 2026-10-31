# Clean Sheet: Dotfiles on mise Alone

**Status:** Proposed, 2026-10-31; decisions recorded 2026-10-31. Researched against mise 2026.10.25 docs (main branch) and binary.

This document asks what this repo would look like if we designed it today, on mise alone. It keeps every feature we rely on and drops any of our implementations that mise now provides. Each claim below is marked **Tested** (run against the 2026.10.25 binary on Linux), **Docs** (read, not run), or **Mac** (needs a test on macOS before we depend on it).

## The short answer

mise now covers most of what this repo builds by hand: linking, directories and permissions, macOS defaults, trust, tool and package upgrades, aliases, directory hooks and task arguments. Four things stay ours, because mise has no concept for them:

1. **GitHub identity:** login, SSH key, signing key, `allowed_signers`
2. **Cloning every repo you own** into `~/dev`
3. **Projects as a concept:** list, switch (`cd`), show, archive
4. **Sharing this Mac's changes** (`dsync`): mise's own sync covers its history repo, never your checkout

The result is one framework instead of two. Stow goes, most of the bootstrap task becomes declarations, and the project layer shrinks from zsh libraries to mise tasks with a thin `cd` shim.

```
                    today                                   clean sheet
┌────────────────────────────────────────┐   ┌────────────────────────────────────────┐
│ mise.sh: CLT, Homebrew, mise, clone    │   │ mise.sh: CLT, mise, clone              │
│ .mise.toml: packages, shell            │   │ mise.toml: packages, shell, dirs,      │
│ .mise/tasks/bootstrap (zsh, 125 lines) │   │   defaults, trust, groups, aliases     │
│   mkdir · stow loop · chmod · trust    │   │                                        │
│   claude curl · defaults · GitHub      │   │ .mise/tasks/bootstrap (ours, smaller)  │
│   clone loop · missing secrets         │   │   GitHub identity · clone loop         │
│ GNU Stow (13 packages)                 │   │ dotfile_groups (same 13 directories)   │
│ lib/*.sh (1,550 lines of zsh)          │   │ global tasks with #USAGE + cd shim     │
│ .zshrc aliases, chpwd hook             │   │ [shell_alias], [hooks]                 │
└────────────────────────────────────────┘   └────────────────────────────────────────┘
```

## Feature map

### Machine setup

| Feature | Today | Clean sheet | Fit | Evidence |
|---|---|---|---|---|
| Install Homebrew | `mise.sh` runs Homebrew's installer | Nothing. The `brew:` manager installs bottles into `/opt/homebrew` itself, creating the prefix with sudo | Full, Apple Silicon only | Docs `bootstrap/packages/brew.md:7-10,37,44-50`. **Mac:** on 2026.9.x shadow skipped every `brew:` package until Homebrew existed |
| Install mise | `brew install mise` | `curl https://mise.run \| sh` (`~/.local/bin`) | Full | Docs `bootstrap/setup.md:260` |
| Clone and hand over | `git clone` then `mise bootstrap` | Same, or `mise bootstrap --from <url> --from-dir ~/.dotfiles` | Full | Docs `from-repository.md:184-232`. **Mac:** the CLT `git` stub |
| Formulae, casks, fonts | `[bootstrap.packages]` | Same; taps as qualified names (`brew:owner/tap/f`); `mas:` for App Store | Full | Docs `brew.md:98-126`, `mas.md` |
| Upgrade everything | `mup` = `bootstrap packages upgrade` | `mup` = `mise bootstrap --only packages,tools --upgrade`: packages and global tools in one run | Full | Done in phase 1 |
| Login shell | `[bootstrap.user] login_shell` | Same | Full | Tested (dry run) |
| `~/dev`, `~/.local/bin`, `~/.ssh` 0700 | `mkdir` before stow | Phase 2: groups make the first two unnecessary; `~/.ssh` 0700 moves with the linking | Full | Tested |
| Global tools | `mise install` in task | Bootstrap step 16 | Full | Docs `bootstrap.md:152` |
| Trust `~/dev` projects | `mise trust` in bootstrap, mkproject, cloneproject, updateproject | `trusted_config_paths = ["~/dev"]` (global) | Full | Done in phase 1; tested: `~/dev` and below load, elsewhere still asks |
| Claude Code | `curl claude.ai/install.sh` | Native installer (unchanged). Claude Code updates itself, which mise warns fights its installs (`self-updating-tools.md:12-16`); mise tools are on PATH only in activated shells, while `~/.local/bin` is on PATH everywhere | None by choice | Docs |
| Screenshot folder | `defaults write` in task | Task (unchanged): `[bootstrap.macos.defaults]` stores values as written, so `~` would need the username spelled out | None | Mac: `~` stored literally (`bootstrap.md:392`) |
| GitHub login, SSH key, signing | Task | Task (unchanged) | None | No bootstrap section covers it |
| Clone every repo you own | `gh repo list` loop → `cloneproject` | Task (unchanged). `[bootstrap.repos]` needs each path declared, can't list a user's repos | None | Docs `repos.md:43-128` |
| Preview without touching `$HOME` | `HOME_DIR` seam, our own previews | `HOME=<scratch>`, `--dry-run`, `mise bootstrap plan --detailed-exitcode` | Full | Tested |

### Dotfiles

| Feature | Today | Clean sheet | Fit | Evidence |
|---|---|---|---|---|
| Link 13 packages | Stow loop, infra exclusions | `[bootstrap] dotfile_groups = [...]`, same directories | Full | Tested: file-by-file links, real directories |
| Directory folding into the repo | Pre-create dirs; agent state still lands in the repo | Gone: groups link file by file | Full | Tested (`~/.claude`, `~/.pi`, `~/dev` stay real) |
| `lazy-lock.json` flows back | Folded `~/.config/nvim` | Group entry `"~/.config/nvim" = { mode = "symlink" }` | Full | Tested |
| ssh config permissions | `chmod go-w` on the repo file | A marked block in a real `~/.ssh/config` (`"~/.ssh/config/dotfiles"`); a copy was rejected because mise overwrote lines other tools add | Full | Done in phase 2 |
| App-written settings (Claude, Pi) | Whole file linked; app writes into the repo | `merge = true` edit: we own our keys, the app keeps its own | Full | Tested |
| Removed package | Unlink by hand | Reported as orphaned; `mise dot apply --prune` | Full | Tested |
| Conflict with an existing file | Stow aborts | Whole run aborts before writing | Full | Tested |
| Drift check | None | `mise dot status --missing` (exit 1) | Full | Docs `reference.md:243` |

### Projects

| Feature | Today | Clean sheet | Fit | Evidence |
|---|---|---|---|---|
| `mkproject <name> [template]` | zsh wrapper → `mkproject:<t>` tasks | The template tasks themselves, with `#USAGE arg "<name>"`, flags, completion; `depends=["mkproject:base {{usage.name}}"]` | Full | Tested (`mise run mkproject:python demo --py 3.13`) |
| Template engine | Shell scripts copy and write files | Same: mise has no project scaffolder; tasks use `MISE_TASK_DIR` | n/a | Docs `mise-cookbook/presets.md` |
| `workon`, `cdproject` | zsh functions | zsh functions (about 20 lines): a task can't `cd` your shell | None | Docs |
| `lsprojects`, `showproject`, `updateproject`, `rmproject` | zsh (`navigate.sh`, `project.sh`) | Global tasks with completion (`complete "name" run="ls ~/dev"`); `confirm` on `--delete` | Full | Docs `task-arguments.md:114-142` |
| Shared `~/dev` tools and env | `~/dev/.mise.toml` | Same (parent config inheritance) | Full | Unchanged |
| Directory hook | zsh `chpwd` (ADR-003) | Global `[hooks] cd` with `{ shell = "zsh", script = ... }` | Full | Tested (`hook-env`) |
| Aliases (`mup`, `dsync`) | `.zshrc` | `[shell_alias]` in global config | Full | Tested |
| Sandbox (`workon -s`) | Own Seatbelt profile: read all but credentials, write project + caches | mise sandbox (Seatbelt on macOS): `deny_read` then `allow_read` (reads are allowlist only); `deny_net` all or nothing | Partial | Docs `sandboxing.md`. **Mac:** whether an interactive shell works in it |

### Secrets and sync

| Feature | Today | Clean sheet | Fit | Evidence |
|---|---|---|---|---|
| Keys in the Keychain | `secret` CLI | Keep `secret`. mise's secrets come from env vars or fnox; mise docs name no Keychain provider | Partial | Docs `bootstrap/secrets.md`, `secrets/fnox.md` |
| Scope a key to one tool | Not possible: all keys reach every `~/dev` project | fnox `secrets = [...]` per task, redacted, never in the shell (experimental, mise ≥ 2026.10.4) | Partial: tasks only, not interactive tools | Docs `fnox.md:7-48,176-226` |
| Report missing secrets | `include/secrets` loop | `[env] KEY = { required = "..." }`, or `mise bootstrap secrets status --missing` | Partial | Docs |
| Sync the dotfiles checkout | `dsync` | `dsync` (unchanged). mise: "keep that checkout in sync with Git yourself" | None | Docs `dotfiles/sync.md:101-107` |
| Tool lockfile | None (everything `latest`) | `lockfile = true`, `mise lock --global`, `mise lock --bump` | Full; brew packages unlocked | Docs `mise-lock.md` |

## What we'd adopt, and what we'd decline

**Adopt.** `dotfile_groups`, `[bootstrap.directories]`, `[bootstrap.macos.defaults]` for values that don't depend on the home directory, `trusted_config_paths`, `mise bootstrap --upgrade`, `[shell_alias]`, global `[hooks]`, `#USAGE` on every project command, `lockfile = true`, and `HOME=` plus `plan` and `status --missing` as test seams.

**Decline for now:**
- **History tracking and `mise dot origin`.** It's a second repo of auto-saved edits; ADR-009 chose deliberate commits.
- **Monorepo mode for `~/dev`.** It renames every project's tasks to `//name:task`, trusts everything under the root, and needs a stub task in each project before `//...:pull` reaches it. A plain loop task does `updateproject` with less ceremony.
- **`[bootstrap.repos]`** for owned repos. It needs every path declared by hand.
- **Claude Code as a mise tool.** It updates itself, and mise's docs warn that a self-updating tool either writes into mise's install directory or installs a second copy. A mise tool is also on PATH only in activated shells, while the native install in `~/.local/bin` is reachable from editors and GUI apps too.
- **The mise sandbox as a direct replacement.** Its allowlist-only reads are stricter than our credentials blocklist; tools that read `~/.gitconfig`, `~/.npmrc` and the like need each one listed. It's a better fit for running an agent as a task than for an interactive shell. Evaluate it on a Mac.
- **fnox.** Per-task scoping is the real win, but it doesn't cover interactive tools (Pi), and we haven't confirmed a Keychain backend.

## Risks

- **Version floor.** Groups need a recent mise; the 2026.9.8 binary rejected `dotfile_groups`. Every Mac must run 2026.10.x or later before the groups change lands.
- **A mise bug in groups.** A permissions-only entry for a directory inside a group cuts it out of the walk. mise then removes the links beneath it immediately, without `--prune`, and deletes the emptied directory. Both behaviors contradict the docs (`groups.md:184-186`, `managed.md:305`). The documented pattern above avoids it; worth reporting upstream.
- **Switching an existing Mac requires unstowing first.** Tested: applying over Stow's links, as `groups.md:251` says you can, failed partway. mise copied the ssh config through Stow's `~/.ssh` link onto itself, which **deleted `ssh/.ssh/config` from the repo**, then stopped. Running `stow -D` on every package first gives a result identical to a fresh Mac. The migration must unstow, then apply.
- **Unattended upgrades.** A launchd job running `mise bootstrap --upgrade` would stall on casks that need sudo.

## Phase 0 results

Run on macOS 27.2 (arm64) with mise 2026.10.24, against GitHub's main.

| Question | Result |
|---|---|
| Does `brew:` need Homebrew? | **No.** With `brew` off PATH, the preview read `pour sl/5.02`: mise pours the bottle itself. `/opt/homebrew` already existed, so creating the prefix on a fresh Mac is still untested. |
| Groups on a fresh home | **Works.** Real directories (`~/dev`, `~/.local/bin`, `~/.claude`, `~/.pi`); `~/.ssh` 700 and its config 600; nvim linked as a whole directory; second apply a no-op; `dot status --missing` clean; nothing written into the repo. |
| Pi merge | **Works.** Pi's `lastChangelogVersion` kept, our `defaultModel` restored. |
| Applying over Stow's links | **Unsafe**, the same as on Linux: it deleted `ssh/.ssh/config` from the repo. Unstowing first gave a clean result. |
| `~` in macOS defaults | **Not expanded.** This Mac's stored value is the literal `~/Pictures/Screenshots` (written by the old installer), and mise called the same literal "already set". Paths under the home directory stay in our task, which writes `$HOME/...`. |
| Bootstrap plan | **Blocked by one cask.** An interrupted Homebrew upgrade left two `mactex` Caskroom versions, and mise refuses to plan any package until Homebrew's metadata is repaired. mise is strict where `brew` tolerates leftovers: expect to clean Homebrew state when an existing Mac switches. |

## Plan

Each phase ships on its own and leaves a working system.

| Phase | Change | Removes | Proves first |
|---|---|---|---|
| 0. Mac spike | `bash tests/spike/mise-native.sh` on one Mac (scratch mise, scratch homes, previews only) | Nothing | `brew:` without Homebrew; groups from a fresh home and from Stow; Pi merge; `~` in macOS defaults |
| 1. Trust and upgrades (done) | `trusted_config_paths`; `mup` upgrades packages and tools | Four `mise trust` calls | `tests/bootstrap.bats`, `tests/project.bats` |
| 2. Groups replace Stow (done) | `dotfile_groups`, nvim whole-dir entry, ssh config block; a pre-dotfiles hook unstows existing Macs and creates `~/.ssh`; `mise run preview`; ADR-010 supersedes ADR-001 | `stow` package, stow loop, mkdirs, chmod, `_DOTFILES_INFRA`, `HOME_DIR` | `tests/bootstrap.bats` through `preview` |
| 2b. Merged app settings | Claude Code and Pi settings as `merge = true` edits | App state in git (`lastChangelogVersion`, `model`) | Next |
| 3. Projects as tasks | `#USAGE` and completion on every command; `[shell_alias]`; global `[hooks]` | Most of `lib/` (keep the `cd` shim); ADR-003 superseded | `tests/project.bats` against `mise run` |
| 4. Bootloader | Drop Homebrew from `mise.sh` if phase 0 confirms it | Homebrew installer call | Fresh-Mac run on shadow |
| 5. Secrets | Decide fnox from phase 0 findings (the sandbox stays ours) | Possibly `secret env` | Mac tests |

## Decisions

1. **Every Mac is Apple Silicon.** `brew:` runs everywhere, so phase 4 drops Homebrew's installer once phase 0 confirms it on a fresh Mac.
2. **The sandbox stays a deny-list.** Agents increasingly need the whole machine: toolchains, caches, other repos, Docker. A deny-list grants that and blocks known secrets. An allowlist breaks each time an agent reaches somewhere new. The tradeoff is that a deny-list fails open: a credential stored somewhere new is readable until the profile names it, and the Keychain is already readable. We keep our Seatbelt profile for `workon -s`. mise's sandbox stays an option for narrow, scripted runs where the reads are known in advance.
3. **App settings become merged keys**, as below.

### Merged settings: an example

Today `~/.pi/agents/settings.json` is a link into the repo, so every write Pi makes lands in git. That includes `lastChangelogVersion`, which changes on every Pi update and has nothing to do with configuration:

```
~/.pi/agents/settings.json  →  ~/.dotfiles/pi/.pi/agents/settings.json   (one file, shared)

{
  "lastChangelogVersion": "0.67.1",      ← Pi writes this; it shows up in dsync
  "defaultProvider": "openai-codex",
  "defaultModel": "gpt-5.4",
  "packages": [ ... ]
}
```

With a merge, the repo holds only the keys we decide on. The live file becomes a regular file that Pi owns, and `mise dot apply` writes our keys into it:

```toml
# .mise.toml
[dotfile_groups.pi.entries]
"~/.pi/agents/settings.json/ours" = { merge = true }
```

```
repo: pi/.pi/agents/settings.json        live: ~/.pi/agents/settings.json (regular file)
{                                        {
  "defaultProvider": "openai-codex",       "lastChangelogVersion": "0.68.0",   ← Pi's, stays local
  "defaultModel": "gpt-5.4",        ──▶    "defaultProvider": "openai-codex",  ← ours, enforced
  "packages": [ ... ]                      "defaultModel": "gpt-5.4",          ← ours, enforced
}                                          "packages": [ ... ]                 ← ours, enforced
                                         }
```

- **Pi changes a key we own** (you switch models in Pi): the next `mise dot apply` puts ours back. Make the change in the repo instead, and `dsync` takes it to every Mac.
- **Pi adds a key we don't own:** it stays on this Mac and never reaches git.
- **Arrays are replaced, not merged.** `packages` is ours as a whole list.
- **Removing a key from the repo doesn't remove it from the live file** (`edits.md:121-124`). To retire a key everywhere, set it to its default rather than deleting it.

Claude Code works the same way. The repo keeps `permissions`, `env`, `sandbox`, `hooks`, `statusLine` and `defaultMode`. Claude keeps what it writes: `enabledPlugins` (from `/plugin`), `effortLevel` (from `/effort`) and the announcement state. One caution: `permissions.allow` is an array we own, so an "always allow" rule Claude saves to the user file is replaced on the next apply. Claude normally saves those to the project's `.claude/settings.local.json`, which this doesn't touch.

A key can also be a default rather than enforced: `merge = "missing"` writes it only when the live file doesn't have it, and the app may change it afterwards. That fits `defaultModel` if you'd rather switch models on one Mac without the next apply reverting it. Using one enforced edit and one default edit on the same file is documented but untested.
