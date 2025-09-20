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

Enhanced project management via mise wrapper:
```sh
# Create projects with templates
~/ $ mkproject example python
~/dev/example/ $ ls -al
.rw-rw-r-- 0 steve 29 June 09:41 .mise.toml

# Clone GitHub projects
~/ $ cloneproject gh kulesh/example
~/dev/example/ $ git remote -v
origin  git@github.com:kulesh/example.git (fetch)

# Switch between projects (with tab completion)
~/ $ workon example
~/dev/example/ $ showproject
Project: example
Location: /Users/steve/dev/example
```

Available templates: `base`, `python`, `fastapi`, `ruby`, `rails`. Use `lsprojects` to see all projects.

## Toolchain
This is an ever evolving list of tools (see Brewfile for more):
* [Neovim](http://neovim.io/) with [CodeCompanion](https://github.com/olimorris/codecompanion.nvim) - editor and AI
* [Ghostty](http://ghostty.org/) - Terminal
