# Architecture

## One Framework

```
┌─────────────────────────────────────────────────────────────────┐
│                     ~/.dotfiles/  (mise)                        │
│                                                                 │
│  System packages (brew:)     Dotfile groups, linked into $HOME  │
│  Dev tools & runtimes        Bootstrap orchestration            │
│  Project task runner         Our task: GitHub, signing, clones  │
│               │                              │                  │
│               ▼                              ▼                  │
│  /opt/homebrew                    ~/.zshrc → zsh/.zshrc         │
│  ~/dev/<org>/<repo>/.mise.toml    ~/.config/nvim → nvim/…       │
└─────────────────────────────────────────────────────────────────┘
```

## Bootstrap Flow

```
bash <(curl -fsSL .../mise.sh)
        │
        ▼
┌───────────────────────────────────────────┐
│ mise.sh (bootloader)                      │
│   1. Xcode CLI tools (waits for dialog)   │
│   2. Homebrew                             │
│   3. mise (via brew)                      │
│   4. git clone → ~/.dotfiles              │
│   5. mise trust && mise bootstrap         │
└────────┬──────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────────┐
│ mise bootstrap (reads .mise.toml)         │
│   1. [bootstrap.packages] → formulae,     │
│      casks, fonts                         │
│   2. pre-dotfiles hook: refuse keys or    │
│      projects inside the repo, remove     │
│      Stow's links, mkdir ~/.ssh (700)     │
│   3. dotfile groups → links into $HOME;   │
│      ~/.ssh/config gets a marked block    │
│   4. [bootstrap.user] → chsh to zsh       │
│   5. .mise/tasks/bootstrap                │
│      mise install → Claude Code           │
│      → macOS defaults                     │
│      → gh auth login (SSH key → GitHub)   │
│      → clone own repos: ~/dev/<owner>/…   │
└───────────────────────────────────────────┘
```

## Project Commands

Each command is a mise task with a short alias; the tasks live in `~/.config/mise/tasks/project` ([ADR-011](adrs/011-project-commands-as-mise-tasks.md)).

```
workon demo<Tab>                     alias → mise -C / run project:workon demo
      │                              completion: mise lists projects (usage spec)
      ▼
project:workon (a child process)     resolves demo to ~/dev/kulesh/demo
      │                              writes it to $DOTFILES_FOLLOW
      ▼
before the next prompt               lib/follow.zsh: cd ~/dev/kulesh/demo
      │
      ▼
chpwd                                lib/sandbox.sh: .sandbox marker? enter the sandbox
```

`-C /` keeps the current project's config from loading, or being trusted, on the way. Commands that need to know where you are (`showproject`, `cdproject`, `updateproject`, `rmproject`) receive it as a hidden `--from "$PWD"`.

## Sync Flow

Each Mac has its own checkout; `dsync` reconciles it with GitHub ([ADR-009](adrs/009-dsync-reconciles-macs.md)).

```
Mac A ~/.dotfiles ──┐                 ┌── Mac B ~/.dotfiles
  tools write       │   dsync         │
  through links     ▼                 ▼
          commit? ─▶ pull --rebase ─▶ conflict? ─▶ lazygit
                         │
                         ├─▶ push (if ahead)
                         └─▶ mise bootstrap (if anything came in)
```

## Component Map

```
~/.dotfiles/
│
├── mise.sh                    Bootloader: installs prerequisites, runs mise bootstrap
├── .mise.toml                 Bootstrap config: packages, dotfile groups, login shell
├── .mise/tasks/bootstrap      Bootstrap task: GitHub, signing, Claude Code, clones
├── .mise/tasks/preview        Link into a scratch home, print the machine-level steps
├── .mise/tasks/sync           dsync: commit, pull --rebase, push, re-bootstrap
├── include/shared_vars.sh     PROJECT_DIR
│
├── lib/                       The parts that must run inside your shell
│   ├── follow.zsh             Go where a command says, before the next prompt
│   ├── reload.zsh             Reload when the shell's own config changes
│   └── sandbox.sh             macOS sandbox-exec lifecycle and chpwd hooks
│
├── mise/.config/mise/
│   ├── config.toml            Runtime config: settings, tools, [shell_alias] (linked)
│   ├── tasks/project/         Project commands: new, clone, list, show, update,
│   │                          remove, workon, root, types; _lib.zsh helpers
│   └── tasks/mkproject/       Project templates
│           ├── _shared/       AGENTS.md header
│           ├── base.sh        Git init, README, .gitignore
│           ├── python.sh      pyproject.toml + uv
│           ├── fastapi.sh     Async API scaffold
│           ├── rust.sh        Cargo workspace
│           ├── typescript.sh  Bun + Ink monorepo
│           ├── ruby.sh        Bundler setup
│           ├── rails.sh       Full MVC
│           ├── convex.sh      Next.js + Convex
│           └── tools/         Tool installation tasks (python, rust, etc.)
│
├── <tool>/                    Dotfile groups, listed in .mise.toml
│   └── .config/<tool>/        Linked file by file into ~/.config/<tool>/
│
├── sandbox/.config/sandbox/
│   └── profiles/default.sb    macOS sandbox-exec profile
│
├── docs/                      Architecture and decision records
│   ├── architecture.md        This file
│   └── adrs/                  Architecture Decision Records
│
└── tests/                     bats-core tests for shell libraries
```

## Data Flow: Project Lifecycle

```
mkproject "api" "fastapi"
        │
        ▼
┌──────────────────────┐     ┌───────────────────────────────┐
│ ~/dev/<login>/api    │────▶│ ~/dev/<login>/mise.toml       │
│ (mkproject org/api:  │     │ (monorepo root, first project │
│  ~/dev/org/api)      │     │  of the org; trusted by path) │
└────────┬─────────────┘     └───────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ mise run mkproject:fastapi              │
│   depends: mkproject:base               │
│   depends: mkproject:tools:python       │
│                                         │
│   1. base.sh → git init, README         │
│   2. tools/python.sh → mise use python  │
│   3. fastapi.sh → scaffold, uv install  │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ write_agent_docs                        │
│   _shared/AGENTS.header.md              │
│   + fastapi/AGENTS.project.md           │
│   → AGENTS.md (every agent reads it)    │
└─────────────────────────────────────────┘
```

## Data Flow: Sandbox Entry

```
cd ~/dev/sandboxed-project   (or: workon project -s)
        │
        ▼
┌───────────────────────────────┐
│ _sandbox_entry_chpwd          │
│   detects .sandbox + .mise.toml│
└────────┬──────────────────────┘
         │
         ▼
┌───────────────────────────────────────────┐
│ _workon_sandboxed                         │
│   makes $SANDBOX_EXIT_FILE (mktemp)       │
│   sandbox-exec -f default.sb              │
│     -D HOME=$HOME                         │
│     -D PROJECT_DIR=~/dev/org/project      │
│     -D SSH_REAL=/real/path/to/.ssh        │
│   → spawns /bin/zsh -i inside sandbox     │
└────────┬──────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────────┐
│ Inside sandbox:                           │
│   writes "entered" to the exit file       │
│   cd outside project → writes the dir,    │
│     exits; the outer shell goes there     │
│   exit → the outer shell closes too       │
│   never started (file empty) → the outer  │
│     shell stays, unsandboxed, and says so │
│                                           │
│ Writes: allowed, except what the Mac runs │
│   later (ADR-002): shell startup, the     │
│   dotfiles, tool configs, .git hooks      │
│ Reads blocked: SSH private keys, ~/.aws,  │
│   browser data                            │
└───────────────────────────────────────────┘
```
