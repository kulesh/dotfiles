# dotfiles

Simple OS X specific dotfiles and install/revert scripts to make life easy and colorful.
## install
To install the dotfiles:
```sh
xcode-select --install # to install developer tools
git clone https://github.com/kulesh/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
/bin/zsh install.sh
```
This poor man's install backs up the current dotfiles about to be
replaced every time it is run.

## revert [broken]
~~To revert to the previous version:
```sh
cd ~/.dotfiles
/bin/zsh revert.sh
```
Revert does not uninstall packages; only reverts the dotfiles. Looks
like install and revert can be run multiple times to switch between
latest and prior versions of the dotfiles.
~~

## Toolchain
This is an ever evolving list of tools (see Brewfile for more):
* [Homebrew](https://brew.sh/) - for managing system-wide apps
* [mise-en-place](https://mise.jdx.dev/) - for managing development environments and dependencies
* [Neovim](http://neovim.io/) with [CodeCompanion](https://github.com/olimorris/codecompanion.nvim) - editor and AI
* [Ghostty](http://ghostty.org/) - Terminal
