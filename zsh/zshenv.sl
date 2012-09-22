#setup PATH to work with brew
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
source "`brew --prefix`/etc/grc.bashrc"

#default location of things
export DOTFILES=$HOME/.dotfiles
export PROJECTS=$HOME/dev

#Setup virtualenv variables
export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/dev
export VIRTUALENVWRAPPER_HOOK_DIR=$WORKON_HOME/hooks
export VIRTUALENVWRAPPER_LOG_DIR=$WORKON_HOME/logs
export VIRTUALENVWRAPPER_TMPDIR=$WORKON_HOME/tmp
export VIRTUALENVWRAPPER_VIRTUALENV_ARGS='--no-site-packages'

#Make pip play well with virtualenvwrapper
export PIP_RESPECT_VIRTUALENV=true
export PIP_VIRTUALENV_BASE=$WORKON_HOME
