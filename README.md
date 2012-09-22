# dotfiles
Some simple dotfiles and install/revert scripts to make life easy and colorful.
## install
To install the dotfiles
```sh
git clone https://github.com/kulesh/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
source install.sh
```
This poor man's install backs up the files every time it is run.

## revert
The <code>install.sh</code> backs up existing dotfiles. You can revert to an older version by
```sh
cd ~/.dotfiles
source revert.sh
```
Revert can be run multiple times to restore files from the latest backups.
