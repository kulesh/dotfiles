#auto complete
autoload -U compinit
compinit

#setup virtualenvwrapper
VIRTUALENV_WRAPPER_SOURCE=/usr/local/bin/virtualenvwrapper.sh
if [ -f $VIRTUALENV_WRAPPER ]
then
    source $VIRTUALENV_WRAPPER
fi
