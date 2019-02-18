#setup PATH to work with brew
export PATH=/usr/local/opt/mysql@5.6/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin
PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
PATH="$HOME/.cargo/env:$PATH"

#default location of things
export DOTFILES=$HOME/.dotfiles
export PROJECTS=$HOME/dev

umask 0002
