#setup PATH to work with brew
export PATH=/usr/local/opt/mysql@5.6/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin
PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
PATH="$HOME/.cargo/env:$PATH"

#default location of things
export DOTFILES=$HOME/.dotfiles
export PROJECTS=$HOME/dev

#Setup virtualenv variables
# export WORKON_HOME=$HOME/.virtualenvs
# export PROJECT_HOME=$HOME/dev
# export VIRTUALENVWRAPPER_HOOK_DIR=$WORKON_HOME/hooks
# export VIRTUALENVWRAPPER_LOG_DIR=$WORKON_HOME/logs
# export VIRTUALENVWRAPPER_TMPDIR=$WORKON_HOME/tmp
# export VIRTUALENVWRAPPER_VIRTUALENV_ARGS='--no-site-packages'
#
# #Make pip play well with virtualenvwrapper
# export PIP_RESPECT_VIRTUALENV=true
# export PIP_VIRTUALENV_BASE=$WORKON_HOME
#
umask 0002
