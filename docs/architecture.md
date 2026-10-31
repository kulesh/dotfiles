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
│  ~/dev/project/.mise.toml         ~/.config/nvim → nvim/…       │
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
│      → cloneproject each own repo → ~/dev │
└───────────────────────────────────────────┘
```

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
├── lib/                       Shell libraries (sourced at shell startup)
│   ├── misewrapper.sh         Entrypoint — loads sub-modules
│   ├── project.sh             mkproject, cloneproject, rmproject, updateproject
│   ├── navigate.sh            workon, cdproject, lsprojects, showproject
│   ├── sandbox.sh             macOS sandbox-exec lifecycle and hooks
│   └── git_utils.sh           Git introspection utilities
│
├── mise/.config/mise/
│   ├── config.toml            Runtime config: settings, tools (linked)
│   └── tasks/mkproject/       Project templates
│           ├── _shared/       CLAUDE.md and AGENTS.md headers
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
┌─────────────────┐     ┌──────────────────┐
│ Create ~/dev/api │────▶│ mise trust .toml  │
└────────┬────────┘     └──────────────────┘
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
│ _mkproject_generate_docs                │
│   _shared/CLAUDE.header.md              │
│   + fastapi/CLAUDE.project.md           │
│   → CLAUDE.md, AGENTS.md               │
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
│   sandbox-exec -f default.sb              │
│     -D HOME=$HOME                         │
│     -D PROJECT_DIR=~/dev/project          │
│     -D SSH_REAL=/real/path/to/.ssh        │
│   → spawns /bin/zsh -i inside sandbox     │
└────────┬──────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────────┐
│ Inside sandbox:                           │
│   _sandbox_chpwd monitors PWD             │
│   cd outside project → exit 42            │
│   explicit exit → exit 0                  │
│                                           │
│ Writes allowed: project dir, ~/.cache,    │
│   ~/.config, ~/.local, /tmp               │
│ Writes blocked: ~/.ssh, ~/.zshrc,         │
│   ~/.gitconfig, /opt/homebrew, /System    │
│ Reads blocked: SSH private keys, ~/.aws,  │
│   browser data                            │
└───────────────────────────────────────────┘
```
