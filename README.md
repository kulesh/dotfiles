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

This installs Xcode CLI tools, Homebrew, and mise, clones the repo to `~/.dotfiles`, then runs `mise bootstrap`: system packages, login shell, dotfile symlinks, global tools, and macOS settings. It finishes by logging you in to GitHub in the browser, which creates an SSH key and adds it to your account for pushing and for signing commits, then clones every repo you own (no forks or archived repos) into `~/dev` as a managed project.

To re-run on an existing machine:

```sh
cd ~/.dotfiles
mise bootstrap
```

To try the symlinks without touching your real `$HOME`, point `HOME_DIR` at an empty scratch directory. Links are created there for real; the steps that would change the machine (`mise install`, macOS defaults) are only previewed:

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

System packages are declared in `mise/.config/mise/config.toml` under `[bootstrap.packages]`.

```sh
# Add a formula
mise bootstrap packages use brew:foo

# Add a cask
mise bootstrap packages use brew-cask:bar

# Check what's installed vs declared
mise bootstrap packages status

# Install only packages
mise bootstrap --only packages
```

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
| **Read** | Everything except secrets | `~/.ssh/*` (private keys), `~/.aws`, keychains |
| **Write** | Project dir, `~/.cache`, `~/.config`, `~/.local`, `/tmp` | System dirs, shell configs, `~/.ssh`, `~/.gitconfig` |
| **Network** | All outbound | — |

### Sandbox Status

```sh
lsprojects      # Shows 🔒 next to sandboxed projects
showproject     # Shows "Sandbox: enabled/disabled"
```

### Multiple Terminals

Each `workon` spawns an independent sandboxed shell—run as many as you need for the same project (e.g., one for Claude, one for the backend, one for frontend).

## Templates

### Available Templates

| Template | Description |
|----------|-------------|
| **base** | Git, README, .gitignore, CLAUDE.md, AGENTS.md |
| **python** | pyproject.toml structure |
| **fastapi** | Async API with testing setup |
| **ruby** | Bundler setup |
| **rails** | Full MVC structure |

Each template includes a `CLAUDE.project.md` with framework-specific guidance for AI assistants. A shared header lives in `mise/.config/mise/tasks/mkproject/_shared/`, and `mkproject` generates `CLAUDE.md` and `AGENTS.md` in the new project.

### Template Architecture

```
mise/.config/mise/tasks/mkproject/
├── _shared/
│   ├── CLAUDE.header.md   # Shared guidance header
│   └── AGENTS.header.md   # Shared guidance header (Codex)
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
   If you want Codex-specific guidance, add `AGENTS.project.md` too. If it's missing, `mkproject` reuses `CLAUDE.project.md`.

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

See `[bootstrap.packages]` in `mise/.config/mise/config.toml` for the full list. Highlights:
- [Neovim](http://neovim.io/) with [CodeCompanion](https://github.com/olimorris/codecompanion.nvim) - editor and AI
- [Ghostty](http://ghostty.org/) - terminal
- [mise](https://mise.jdx.dev/) - version management and task runner
- [starship](https://starship.rs/) - shell prompt
