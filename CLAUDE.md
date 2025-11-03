# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## First Things First

BEFORE ANYTHING ELSE: run 'bd onboard' and follow the instructions

## Repository Overview

This is a macOS-specific dotfiles management system that uses:

- **Homebrew** for system-wide dependencies via Brew Bundles
- **mise-en-place** for development environments and project-level dependencies
- **GNU Stow** for managing dotfiles symlinks

The system is designed to be evolving, grokable, and contained to the project directory.

## Key Commands

### Installation

```bash
# Initial setup (run from ~/.dotfiles)
/bin/zsh install.sh
```

### Project Management (via mise wrapper)

```bash
# Create a new project
mkproject <project_name> [template_type]

# Clone a GitHub project
cloneproject gh <user>/<repo>
cloneproject <github_url>

# Switch to existing project
workon <project_name>

# List all projects
lsprojects [--type=cloned|created] [--tools]

# Show current project info
showproject

# Update a cloned project
updateproject [project_name]

# Remove project (archives by default)
rmproject <project_name> [--delete]

# List available project templates
list_project_types
```

### Navigation

```bash
# Change to current mise project root
cdproject
```

## Architecture

### Directory Structure

```
~/.dotfiles/
├── install.sh              # Main installation script
├── include/shared_vars.sh   # Shared configuration variables
├── lib/misewrapper.sh       # Project management functions
├── brew/Brewfile           # Homebrew dependencies
├── mise/.config/mise/      # Mise configuration and tasks
│   ├── config.toml         # Global mise settings
│   └── tasks/mkproject/    # Project templates
├── <tool>/                 # Individual tool configurations
│   └── .config/<tool>/     # Stowed to ~/.config/<tool>/
└── dev/                    # Dev directory structure template
```

### Project Templates

Available in `mise/.config/mise/tasks/mkproject/`:

- `base.sh` - Basic project with git init, README, .gitignore
- `python.sh` - Python project with pyproject.toml structure
- `fastapi.sh` - FastAPI project template
- `ruby.sh` - Ruby project template
- `rails.sh` - Rails project template

### Key Configuration Files

#### Shared Variables (`include/shared_vars.sh`)

- `HOME_DIR=$HOME` - Home directory location
- `PROJECT_DIR="$HOME_DIR/dev"` - Where projects are created
- `STOWED_PACKAGES` - Array of directories to stow

#### Mise Configuration (`mise/.config/mise/config.toml`)

- `not_found_auto_install = true` - Auto-install missing tools
- `experimental = true` - Enable experimental features
- Project templates accessed via `mise tasks ls` and `mise run mkproject:<type>`

### Project Management System

The mise wrapper (`lib/misewrapper.sh`) provides enhanced project management:

1. **Project Creation**: `mkproject` creates projects in `~/dev/` with mise config
2. **GitHub Integration**: `cloneproject` combines project creation with git clone
3. **Project Discovery**: Automatic detection of mise projects via `.mise.toml` files
4. **Tab Completion**: Zsh completion for all project commands
5. **Git Integration**: Status checking, uncommitted change warnings
6. **Archiving**: Safe project removal with archive option

### Stow Package Structure

Each tool directory contains dotfiles that get symlinked to `$HOME`:

```
tool_name/
└── .config/tool_name/  # → ~/.config/tool_name/
    └── config_file
```

Stowed packages: zsh, git, ghostty, ssh, mise, nvim, brew, starship, dev

## Development Workflow

1. Use `mkproject <name> <type>` to create new projects
2. Use `workon <name>` to switch between projects
3. Use `lsprojects` to see all available projects
4. Use `updateproject` to pull latest changes for cloned projects
5. Use `showproject` to see current project status and git info

## Dependencies

Core tools installed via Brewfile:

- mise - Version management and task runner
- stow - Symlink management
- fd, ripgrep, fzf - File searching and navigation
- neovim, zellij, ghostty - Development environment
- git-delta, lazygit - Git tooling
- starship, zoxide - Shell enhancements

Development tools auto-installed per project via mise when needed.

