# dotfiles

A simple macOS specific dotfiles management system for making my developer experience consistent across the many Macs I use. Design tenets (in tension) are:
1. Evolving -- breaking changes can happen
2. Grokable -- I understand how everything works
3. Contained -- changes are local to `$PROJECT_DIR`

Everything runs on [mise-en-place](https://mise.jdx.dev/): system packages, development environments, linking the dotfiles into `$HOME`, and bootstrap orchestration.

## Installation

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/kulesh/dotfiles/main/mise.sh)
```

This installs Xcode CLI tools, Homebrew, and mise, clones the repo to `~/.dotfiles`, then runs `mise bootstrap`: system packages, login shell, dotfile symlinks, global tools, Claude Code, and macOS settings. It finishes by logging you in to GitHub in the browser, which creates an SSH key and adds it to your account for pushing and for signing commits, then clones every repo you own (no forks or archived repos) into `~/dev/<owner>/<repo>` as a managed project.

To re-run on an existing machine:

```sh
cd ~/.dotfiles
mise bootstrap
```

To see what bootstrap would do without touching your real home, preview it. The links are made for real in a scratch directory, with mise's own state kept there too; everything that would change the machine (tool installs, GitHub login and keys, cloning, macOS defaults) is only printed:

```sh
mise -C ~/.dotfiles run preview
```

Each top-level directory (`zsh/`, `git/`, `nvim/`…) mirrors `$HOME` and is linked into it file by file, so `~/dev`, `~/.ssh` and `~/.claude` are always real directories. A Mac set up with GNU Stow moves over on its next bootstrap. See [ADR-010](docs/adrs/010-mise-links-dotfiles.md), and `mise -C ~/.dotfiles dot status` to check the links.

## Quick Start

```sh
# Clone a GitHub project: ~/dev/kulesh/example
cloneproject kulesh/example

# Or create a new project from template: ~/dev/<your login>/my-api
mkproject my-api fastapi

# Switch between projects (tab completion works; org/repo when a name is in two orgs)
workon my-api

# See all your projects
lsprojects

# View current project details
showproject
```

## Commands

Projects live at `~/dev/<org>/<repo>`: a clone under its GitHub owner, a new project under your GitHub login or the org you name. An org directory is a plain folder; tools and `[env]` you put in `~/dev/<org>/mise.toml` reach all its repos. See [ADR-013](docs/adrs/013-projects-grouped-by-org.md).

Each command is a mise task (`mise tasks ls`), so `<command> --help` explains it and Tab completes project names, templates and flags. Commands that move you (`mkproject`, `cloneproject`, `workon`, `cdproject`, and `rmproject` from inside the project) take effect at the next prompt. See [ADR-011](docs/adrs/011-project-commands-as-mise-tasks.md).

| Command | Description |
|---------|-------------|
| `mkproject [org/]name [template]` | Create new project (default: base template, your org) |
| `mkproject [org/]name [template] -n` | Describe the project without creating it |
| `cloneproject <user>/<repo>` | Clone a GitHub repo into `~/dev/<user>` (a URL works too) |
| `workon <project>` | Switch to project: `repo`, or `org/repo` (with tab completion) |
| `workon` | Pick a project with fzf, `showproject` beside it |
| `workon <project> -s` | Switch to project in sandbox mode |
| `lsprojects` | List all projects by org, with metadata |
| `lsprojects --type cloned` | Only cloned (or `created`) projects |
| `lsprojects --tools` | List projects with mise tools |
| `showproject` | Show current project details |
| `cdproject` | Jump to current project root |
| `updateproject [name \| org/]` | Pull latest changes: one project, or every repo in an org (fast-forward only, one question) |
| `rmproject <name>` | Archive project to `~/dev/.archive/<org>` (safe removal) |
| `rmproject <name> --delete` | Permanently delete project |
| `rmproject` | Pick the project to archive with fzf, `showproject` beside it |
| `list_project_types` | Show available templates |

## Package Management

System packages are declared under `[bootstrap.packages]` in `~/.dotfiles/.mise.toml`. mise reads that file only from inside the repo, so package commands run with `-C ~/.dotfiles` (or from that directory). Without it, `packages use` would add the package to whatever project you're in.

```sh
mup                                                   # upgrade all packages and global tools, from anywhere
mise -C ~/.dotfiles bootstrap packages use brew:foo   # add a formula
mise -C ~/.dotfiles bootstrap packages use brew-cask:bar
mise -C ~/.dotfiles bootstrap packages status         # installed vs declared
```

## Keeping Macs in Sync

Tools write through the links into `~/.dotfiles` (plugin lockfiles, agent settings, `packages use`), so each Mac's checkout drifts. One command reconciles it:

```sh
dsync
```

It offers to commit this Mac's changes, rebases them onto GitHub's, pushes, and re-runs `mise bootstrap` if anything came in. If another Mac changed the same lines, it lists the files and opens lazygit. Resolve or abort there; if you leave it unresolved, run `dsync` again later. New shells say when this Mac is out of step (`dotfiles: 2 from other Macs. Run dsync.`). Open shells pick up what dsync brought in by themselves: when a file the shell loaded has changed, it reloads before the next prompt (`lib/reload.zsh`), keeping its directory and exported environment. See [ADR-009](docs/adrs/009-dsync-reconciles-macs.md).

## Secrets

API keys live in the macOS Keychain, not in files.

```sh
secret set ANTHROPIC_API_KEY   # prompts for the value
secret ls                      # names stored on this Mac
secret get ANTHROPIC_API_KEY
secret rm ANTHROPIC_API_KEY
```

A project that calls a model API names each key it uses in its own `.mise.toml`, and gets only those:

```toml
[env]
ANTHROPIC_API_KEY = "{{ exec(command='secret get ANTHROPIC_API_KEY') }}"
```

Every other project gets no keys. That matters because Claude Code bills an `ANTHROPIC_API_KEY` it finds in the environment instead of your subscription. Keychain items don't sync between Macs; `mise bootstrap` lists any key a project names that this Mac is missing. See [ADR-012](docs/adrs/012-projects-name-their-secrets.md), and [ADR-008](docs/adrs/008-secrets-in-keychain.md) for what the Keychain does and doesn't protect.

## Sandboxing

Projects can run in a macOS sandbox that restricts filesystem access—useful for running AI coding agents safely.

### Enable Sandbox

```sh
workon myproject -s    # First time enables sandbox for project
workon myproject       # Subsequent runs auto-enter sandbox
```

### What's Restricted

| Access | Allowed | Blocked |
|--------|---------|---------|
| **Read** | Everything except credentials | SSH private keys, `~/.aws`, `~/.netrc`, GPG keys, browser data |
| **Write** | Everything else: the project, tool state, caches | Whatever your Mac runs later outside the sandbox: shell startup files, `~/Library/LaunchAgents`, the `~/.dotfiles` checkout (agent settings aside), configs that run commands (`~/.config/mise`, `git`, `gh`, `starship`, `ghostty`, `homebrew`, `nvim`, `yazi`, `sandbox`), `~/.local/bin`, `/usr/local`, the project's `.git/hooks` and `.git/config`; plus `~/.ssh`, GPG and AWS keys and system dirs |
| **Network** | All outbound | — |

The Keychain stays readable (git's credential helper needs it), so secrets stored with `secret` are reachable from inside the sandbox. Inside it, push without `-u`: the project's `.git/config` is read-only. Still open: Claude Code's `settings.json` (its hooks), `~/.claude/plugins`, and tools installed under `~/.local/share`. See [ADR-002](docs/adrs/002-sandbox-exec-for-agents.md).

### Sandbox Status

```sh
lsprojects      # Shows 🔒 next to sandboxed projects
showproject     # Shows 🔒 Sandboxed for sandboxed projects
```

### Multiple Terminals

Each `workon` spawns an independent sandboxed shell—run as many as you need for the same project (e.g., one for Pi, one for the backend, one for the frontend).

## Templates

### Available Templates

| Template | Description |
|----------|-------------|
| **base** | Git, README, .gitignore, AGENTS.md |
| **python** | uv, pytest, Ruff, basedpyright; `src/` layout |
| **fastapi** | Async API on the python template, with test client |
| **typescript** | Bun workspace: core library + Ink CLI; Biome, Vitest, TypeScript 7 |
| **convex** | Next.js + Convex + Convex Auth, Tailwind 4, shadcn/ui; Biome |
| **rust** | Cargo workspace (library + binary), rust-analyzer |
| **ruby** | Bundler, RSpec, RuboCop |
| **rails** | `rails new` |

Generated projects pass their own linters, and the editor uses each project's own tools ([ADR-007](docs/adrs/007-editor-uses-project-tooling.md)).

Each template includes an `AGENTS.project.md` with framework-specific guidance for coding agents. A shared header lives in `mise/.config/mise/tasks/mkproject/_shared/`, and `mkproject` generates one `AGENTS.md` in the new project. Every agent reads it, Claude Code included: it reads `AGENTS.md` when a project has no `CLAUDE.md` (v2.1.277 and later).

### Template Architecture

```
mise/.config/mise/tasks/mkproject/
├── _shared/
│   └── AGENTS.header.md   # Shared guidance header
├── base/
│   └── AGENTS.project.md  # Base project guidance
├── fastapi/
│   ├── AGENTS.project.md  # FastAPI-specific guidance
│   └── files/
│       └── .env.example   # Configuration template
└── fastapi.sh             # Generates project structure
```

When you run `mkproject my-api fastapi`:
1. Static files are copied from the template `files/` directory
2. The template script generates framework-specific code
3. `AGENTS.md` is generated from the shared header + the template's guidance
4. Dependencies are installed via mise and package managers

### Adding Custom Templates

1. Create the template directory:
   ```sh
   mkdir mise/.config/mise/tasks/mkproject/mytemplate
   ```

2. Add static files (optional):
   ```sh
   mkdir mise/.config/mise/tasks/mkproject/mytemplate/files
   touch mise/.config/mise/tasks/mkproject/mytemplate/files/.gitignore
   touch mise/.config/mise/tasks/mkproject/mytemplate/AGENTS.project.md
   ```
   Without an `AGENTS.project.md`, `mkproject` uses base's.

3. Create the template script:
   ```sh
   # mise/.config/mise/tasks/mkproject/mytemplate.sh
   #!/usr/bin/env zsh
   #MISE description="Setup my custom project"
   #MISE dir="{{cwd}}"
   #MISE depends=["mkproject:base"]

   echo "Setting up custom project..."

   TEMPLATE_DIR="${0:a:h}/mytemplate/files"
   if [[ -d "$TEMPLATE_DIR" ]]; then
       cp -r "$TEMPLATE_DIR"/. "$PWD/"
   fi
   ```

4. Test: `mkproject test-project mytemplate`

## Toolchain

The full list is `[bootstrap.packages]` in `.mise.toml`. Highlights:
- [Pi](https://github.com/badlogic/pi-mono) - coding agent, with frontier models; installed for `~/dev` by `~/dev/.mise.toml`
- [Claude Code](https://claude.com/claude-code) - coding agent
- [Neovim](https://neovim.io/) - editor, with language servers from each project's own toolchain
- [Ghostty](https://ghostty.org/) - terminal
- [mise](https://mise.jdx.dev/) - packages, tool versions, and task runner
- [starship](https://starship.rs/) - shell prompt

## Documentation

- [Architecture](docs/architecture.md): components and data flows
- [Decision records](docs/adrs/): why things are the way they are
- [Clean sheet on mise](docs/mise-native.md): the plan for moving hand-written setup onto mise features
