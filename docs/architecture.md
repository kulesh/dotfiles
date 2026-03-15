# Architecture

## Three Pillars

```
┌─────────────────────────────────────────────────────────────────┐
│                        ~/.dotfiles/                             │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │   Homebrew    │  │  GNU Stow    │  │   mise-en-place    │    │
│  │              │  │              │  │                    │    │
│  │  System-wide  │  │  Symlinks    │  │  Per-project       │    │
│  │  tools from   │  │  tool configs│  │  dev environments  │    │
│  │  Brewfile     │  │  to $HOME    │  │  and task runner   │    │
│  └──────┬───────┘  └──────┬───────┘  └────────┬───────────┘    │
│         │                 │                    │                │
│         ▼                 ▼                    ▼                │
│  brew install ...   ~/.config/tool/     ~/dev/project/          │
│  brew bundle        ~/.zshrc            .mise.toml              │
│                     ~/.gitconfig        python, node, etc.      │
└─────────────────────────────────────────────────────────────────┘
```

## Component Map

```
~/.dotfiles/
│
├── install.sh                 Bootstrap: Homebrew → Stow → SSH → macOS
├── include/shared_vars.sh     HOME_DIR, PROJECT_DIR, infra exclusions
│
├── lib/                       Shell libraries (sourced at shell startup)
│   ├── misewrapper.sh         Entrypoint — loads sub-modules
│   ├── project.sh             mkproject, cloneproject, rmproject, updateproject
│   ├── navigate.sh            workon, cdproject, lsprojects, showproject
│   ├── sandbox.sh             macOS sandbox-exec lifecycle and hooks
│   └── git_utils.sh           Git introspection utilities
│
├── brew/Brewfile              Declarative system dependencies
│
├── mise/.config/mise/
│   ├── config.toml            Global mise settings
│   └── tasks/mkproject/       Project templates
│       ├── _shared/           CLAUDE.md and AGENTS.md headers
│       ├── base.sh            Git init, README, .gitignore
│       ├── python.sh          pyproject.toml + uv
│       ├── fastapi.sh         Async API scaffold
│       ├── rust.sh            Cargo workspace
│       ├── typescript.sh      Bun + Ink monorepo
│       ├── ruby.sh            Bundler setup
│       ├── rails.sh           Full MVC
│       ├── convex.sh          Next.js + Convex
│       └── tools/             Tool installation tasks (python, rust, etc.)
│
├── <tool>/                    Stow packages (auto-discovered)
│   └── .config/<tool>/        Symlinked to ~/.config/<tool>/
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
