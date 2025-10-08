# dotfiles

A simple macOS specific dotfiles management system for making my developer experience consistent across the many Macs I use. Design tenets (in tension) are:
1. Evolving -- breaking changes can happen
2. Grokable -- I understand how everything works
3. Contained -- changes are local to ``$PROJECT_DIR``

The system does three things:
- Uses [Homebrew](https://brew.sh/) for managing system-wide dependencies using [Brew Bundles](https://docs.brew.sh/Brew-Bundle-and-Brewfile)
- Uses [mise-en-place](https://mise.jdx.dev/) for managing development environments and project level dependencies
- Uses [GNU Stow](https://www.gnu.org/software/stow/) for managing dotfiles

## Getting Started
To install the dotfiles:
```sh
xcode-select --install # to install developer tools
sudo xcodebuild -license
git clone https://github.com/kulesh/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
/bin/zsh install.sh
```
This will install all the dependencies spelled out in the Brewfile and create symlinks to relevant dotfiles.

## Project Management

The system includes a comprehensive project management wrapper around mise that provides scaffolding, templates, and workflow commands.

### Quick Start

```sh
# Create a new FastAPI project with template
~/ $ mkproject my-api fastapi
~/dev/my-api/ $ ls -al
# Includes: CLAUDE.md, .env.example, complete FastAPI structure

# Clone GitHub projects
~/ $ cloneproject gh kulesh/example
~/dev/example/ $ git remote -v
origin  git@github.com:kulesh/example.git (fetch)

# Switch between projects (with tab completion)
~/ $ workon my-api
~/dev/my-api/ $ showproject
Project: my-api
Location: /Users/steve/dev/my-api
```

### Available Templates

Each template includes framework-specific structure, dependencies, and a `CLAUDE.md` file with guidance for AI assistants:

- **base** - Basic project with git, README, .gitignore, and general CLAUDE.md
- **python** - Python project with pyproject.toml structure
- **fastapi** - FastAPI project with async patterns, testing, and API structure
- **ruby** - Ruby project with bundler setup
- **rails** - Rails project with MVC structure and conventions

Use `list_project_types` to see all available templates with descriptions.

### Template Architecture

Templates use a static file + script approach:
```
mise/.config/mise/tasks/mkproject/
├── base/
│   └── CLAUDE.md          # Guidance for all projects
├── fastapi/
│   ├── CLAUDE.md          # FastAPI-specific guidance (overrides base)
│   └── .env.example       # Configuration template
└── fastapi.sh             # Generates project structure
```

When you run `mkproject my-api fastapi`:
1. Static files are copied from the template directory
2. The template script generates framework-specific code
3. Dependencies are installed via mise and package managers

### Key Commands

```sh
# Project creation
mkproject <name> [template]      # Create new project (default: base)
cloneproject gh <user>/<repo>    # Clone and setup GitHub project
cloneproject <github_url>        # Clone from full URL

# Navigation
workon <project>                 # Switch to project (tab completion)
cdproject                        # Jump to current project root

# Information
lsprojects                       # List all projects with metadata
lsprojects --type=cloned         # Filter by type (cloned/created)
lsprojects --tools               # Show mise tools per project
showproject                      # Show current project details

# Maintenance
updateproject [name]             # Pull latest changes (cloned projects)
rmproject <name>                 # Archive project (safe removal)
rmproject <name> --delete        # Permanently delete project

# Templates
list_project_types               # Show available templates
```

### Adding Custom Templates

To create a new template:

1. Create the template directory:
   ```sh
   mkdir mise/.config/mise/tasks/mkproject/mytemplate
   ```

2. Add static files (optional):
   ```sh
   # Add files that should be copied to every project
   touch mise/.config/mise/tasks/mkproject/mytemplate/CLAUDE.md
   touch mise/.config/mise/tasks/mkproject/mytemplate/.gitignore
   ```

3. Create the template script:
   ```sh
   # mise/.config/mise/tasks/mkproject/mytemplate.sh
   #!/usr/bin/env zsh
   #MISE description="Setup my custom project"
   #MISE dir="{{cwd}}"
   #MISE depends=["mkproject:base"]

   echo "Setting up custom project..."

   # Copy static files first
   TEMPLATE_DIR="${0:a:h}/mytemplate"
   if [[ -d "$TEMPLATE_DIR" ]]; then
       cp -r "$TEMPLATE_DIR"/. "$PWD/"
   fi

   # Generate project-specific code here
   ```

4. Test your template:
   ```sh
   mkproject test-project mytemplate
   ```

## Toolchain
This is an ever evolving list of tools (see Brewfile for more):
* [Neovim](http://neovim.io/) with [CodeCompanion](https://github.com/olimorris/codecompanion.nvim) - editor and AI
* [Ghostty](http://ghostty.org/) - Terminal
