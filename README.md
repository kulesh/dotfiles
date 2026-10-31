# dotfiles

A simple macOS specific dotfiles management system for making my developer experience consistent across the many Macs I use. Design tenets (in tension) are:
1. Evolving -- breaking changes can happen
2. Grokable -- I understand how everything works
3. Contained -- changes are local to `$PROJECT_DIR`

The system does two things:
- Uses [mise-en-place](https://mise.jdx.dev/) for system packages, development environments, and bootstrap orchestration
- Uses [GNU Stow](https://www.gnu.org/software/stow/) for managing dotfiles

## Installation

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/kulesh/dotfiles/main/mise.sh)
```

This installs Xcode CLI tools, Homebrew, and mise, clones the repo to `~/.dotfiles`, then runs `mise bootstrap`: system packages, login shell, dotfile symlinks, global tools, Claude Code, and macOS settings. It finishes by logging you in to GitHub in the browser, which creates an SSH key and adds it to your account for pushing and for signing commits, then clones every repo you own (no forks or archived repos) into `~/dev` as a managed project.

To re-run on an existing machine:

```sh
cd ~/.dotfiles
mise bootstrap
```

To try the symlinks without touching your real `$HOME`, point `HOME_DIR` at an empty scratch directory. Links are created there for real; everything that would change the machine (tool installs, GitHub login and keys, cloning, macOS defaults) is only printed:

```sh
HOME_DIR=$(mktemp -d) mise run bootstrap
```

## Quick Start

```sh
# Clone a GitHub project
cloneproject gh kulesh/example

# Or create a new project from template
mkproject my-api fastapi

# Switch between projects (tab completion works)
workon my-api

# See all your projects
lsprojects

# View current project details
showproject
```

## Commands

| Command | Description |
|---------|-------------|
| `mkproject <name> [template]` | Create new project (default: base template) |
| `cloneproject gh <user>/<repo>` | Clone and setup GitHub project |
| `workon <project>` | Switch to project (with tab completion) |
| `workon <project> -s` | Switch to project in sandbox mode |
| `lsprojects` | List all projects with metadata |
| `lsprojects --tools` | List projects with mise tools |
| `showproject` | Show current project details |
| `cdproject` | Jump to current project root |
| `updateproject [name]` | Pull latest changes (cloned projects) |
| `rmproject <name>` | Archive project (safe removal) |
| `rmproject <name> --delete` | Permanently delete project |
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

It offers to commit this Mac's changes, rebases them onto GitHub's, pushes, and re-runs `mise bootstrap` if anything came in. If another Mac changed the same lines, it lists the files and opens lazygit. Resolve or abort there; if you leave it unresolved, run `dsync` again later. New shells say when this Mac is out of step (`dotfiles: 2 from other Macs. Run dsync.`). See [ADR-009](docs/adrs/009-dsync-reconciles-macs.md).

## Secrets

API keys live in the macOS Keychain, not in files. Projects under `~/dev` get them as environment variables.

```sh
secret set ANTHROPIC_API_KEY   # prompts for the value
secret ls                      # names stored on this Mac
secret get ANTHROPIC_API_KEY
secret rm ANTHROPIC_API_KEY
```

Keychain items don't sync between Macs; `mise bootstrap` lists any secret from `include/secrets` that this machine is missing. See [ADR-008](docs/adrs/008-secrets-in-keychain.md) for what this does and doesn't protect.

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
| **Write** | Project dir, `~/.cache`, `~/.config`, `~/.local`, `/tmp` | System dirs, shell configs, `~/.ssh`, `~/.gitconfig` |
| **Network** | All outbound | — |

The Keychain stays readable (git's credential helper needs it), so secrets stored with `secret` are reachable from inside the sandbox.

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
| **base** | Git, README, .gitignore, CLAUDE.md, AGENTS.md |
| **python** | uv, pytest, Ruff, basedpyright; `src/` layout |
| **fastapi** | Async API on the python template, with test client |
| **typescript** | Bun workspace: core library + Ink CLI; Biome, Vitest, TypeScript 7 |
| **convex** | Next.js + Convex + Convex Auth, Tailwind 4, shadcn/ui; Biome |
| **rust** | Cargo workspace (library + binary), rust-analyzer |
| **ruby** | Bundler, RSpec, RuboCop |
| **rails** | `rails new` |

Generated projects pass their own linters, and the editor uses each project's own tools ([ADR-007](docs/adrs/007-editor-uses-project-tooling.md)).

Each template includes a `CLAUDE.project.md` with framework-specific guidance for AI assistants. A shared header lives in `mise/.config/mise/tasks/mkproject/_shared/`, and `mkproject` generates `CLAUDE.md` and `AGENTS.md` in the new project.

### Template Architecture

```
mise/.config/mise/tasks/mkproject/
├── _shared/
│   ├── CLAUDE.header.md   # Shared guidance header
│   └── AGENTS.header.md   # Shared guidance header (Pi, Codex, other agents)
├── base/
│   └── CLAUDE.project.md  # Base project guidance
├── fastapi/
│   ├── CLAUDE.project.md  # FastAPI-specific guidance
│   └── files/
│       └── .env.example   # Configuration template
└── fastapi.sh             # Generates project structure
```

When you run `mkproject my-api fastapi`:
1. Static files are copied from the template `files/` directory
2. The template script generates framework-specific code
3. `CLAUDE.md` + `AGENTS.md` are generated from shared + template-specific docs
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
   touch mise/.config/mise/tasks/mkproject/mytemplate/CLAUDE.project.md
   ```
   For guidance specific to agents that read `AGENTS.md` (Pi, Codex), add `AGENTS.project.md` too. If it's missing, `mkproject` reuses `CLAUDE.project.md`.

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
- [Clean sheet on mise](docs/mise-native.md): proposal to replace Stow and most hand-written setup with mise features
