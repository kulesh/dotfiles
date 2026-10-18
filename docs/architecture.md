# Architecture

## Two Pillars

```
┌─────────────────────────────────────────────────────────────────┐
│                        ~/.dotfiles/                             │
│                                                                 │
│  ┌──────────────────────────┐  ┌──────────────────────────┐    │
│  │      mise-en-place        │  │       GNU Stow            │    │
│  │                           │  │                           │    │
│  │  System packages (brew)   │  │  Symlinks tool configs    │    │
│  │  Dev tools & runtimes     │  │  to $HOME                 │    │
│  │  Bootstrap orchestration  │  │                           │    │
│  │  Project task runner      │  │                           │    │
│  └────────────┬─────────────┘  └────────────┬──────────────┘    │
│               │                              │                   │
│               ▼                              ▼                   │
│  brew install ...                 ~/.config/tool/                │
│  mise bootstrap                   ~/.zshrc                       │
│  ~/dev/project/.mise.toml         ~/.gitconfig                   │
└─────────────────────────────────────────────────────────────────┘
```

## Bootstrap Flow

```
curl https://mise.run | sh          # or: ~/.dotfiles/mise.sh
        │
        ▼
┌───────────────────────────────────────────┐
│ mise.sh (bootloader)                      │
│   1. Install Xcode CLI tools if needed    │
│   2. Install mise                         │
│   3. Clone dotfiles repo                  │
│   4. mise trust && mise bootstrap         │
└────────┬──────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────────┐
│ mise bootstrap (run order)                │
│   1. [bootstrap.packages] → Homebrew      │
│      installs formulae, casks, fonts      │
│   2. [tasks.bootstrap] → tasks/bootstrap  │
│      stow, permissions, macOS defaults    │
│   3. [tools] → uv, etc.                  │
└───────────────────────────────────────────┘
```

## Component Map

```
~/.dotfiles/
│
├── mise.sh                    Bootloader: installs mise, clones repo, bootstraps
├── include/shared_vars.sh     HOME_DIR, PROJECT_DIR, infra exclusions
│
├── lib/                       Shell libraries (sourced at shell startup)
│   ├── misewrapper.sh         Entrypoint — loads sub-modules
│   ├── project.sh             mkproject, cloneproject, rmproject, updateproject
│   ├── navigate.sh            workon, cdproject, lsprojects, showproject
│   ├── sandbox.sh             macOS sandbox-exec lifecycle and hooks
│   └── git_utils.sh           Git introspection utilities
│
├── mise/.config/mise/
│   ├── config.toml            Machine config: settings, packages, bootstrap task
│   └── tasks/
│       ├── bootstrap          Stow + permissions + macOS setup
│       └── mkproject/         Project templates
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
