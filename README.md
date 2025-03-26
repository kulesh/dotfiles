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
git clone https://github.com/kulesh/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
/bin/zsh install.sh
```
This will install all the dependencies spelled out in the Brewfile and create symlinks to relevant dotfiles.

There are some QoL functions available for creating projects:
```sh
~/ $ mkproject example
~/dev/example/ $ ls -al
.rw-rw-r-- 0 steve 29 June 09:41 .mise.toml
~/dev/example/ $ mise use python
~/dev/example/ $ which python
/Users/steve/.local/share/mise/installs/python/3.13.2/bin/python
```

To work on an already created project:
```sh
~/ $ workon example
~/dev/exmaple/ $ ls -al
.rw-rw-r-- 26 steve 29 June 09:41 .mise.toml
```
``workon`` has tab completion.

## Toolchain
This is an ever evolving list of tools (see Brewfile for more):
* [Neovim](http://neovim.io/) with [CodeCompanion](https://github.com/olimorris/codecompanion.nvim) - editor and AI
* [Ghostty](http://ghostty.org/) - Terminal
