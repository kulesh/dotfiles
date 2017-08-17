# dotfiles
Simple OS X specific dotfiles and install/revert scripts to make life easy and colorful.
## install
To install the dotfiles:
```sh
git clone https://github.com/kulesh/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
/bin/zsh install.sh
```
This poor man's install backs up the current dotfiles about to be
replaced every time it is run.

## revert
To revert to the previous version:
```sh
cd ~/.dotfiles
/bin/zsh revert.sh
```
Revert does not uninstall packages; only reverts the dotfiles. Looks
like install and revert can be run multiple times to switch between
latest and prior versions of the dotfiles.

## Toolchain
This is an ever evolving list of tools:
* [Homebrew](https://brew.sh/) for package management
* [Direnv](https://direnv.net/) for project/environment management
* [FZF](https://github.com/junegunn/fzf) backed by [ripgrep](https://github.com/BurntSushi/ripgrep) for discovery
* Git for version control
* [Janus](https://github.com/carlhuda/janus/) for Vim
* [Inconsolata](http://www.levien.com/type/myfonts/inconsolata.html) CLI
  font
