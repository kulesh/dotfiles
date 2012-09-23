#!/bin/sh

source include/shared_vars.sh

BREWED_TOOLS=(grc coreutils hub aspell --lang=en) #tools to install via Homebrew
PIP_TOOLS=(virtualenvwrapper) #tools to install via pip

BACKUP_DIR='' #where we will backup this instance of install

#install pip and friends
install_pip()
{
    if test ! $(which pip)
    then
        echo "     [-] There is no pip. Going to install pip. This will ask for your root password."
        sudo easy_install pip
    fi

    pip install $PIP_TOOLS
}

#install Homebrew and friends
install_homebrew()
{
    #Install homebrew
    if test ! $(which brew)
    then
        echo "     [-] There is no Homebrew. Going to install Homebrew."
        ruby <(curl -fsSkL raw.github.com/mxcl/homebrew/go)
    fi

    #brew me some goodness
    brew install $BREWED_TOOLS
}

#install Janus
install_janus()
{
    vim_home=$HOME/.vim
    echo "     [+] Installing Janus for vim"
    if [ ! -d $vim_home/janus ]
    then
        curl -Lo- https://bit.ly/janus-bootstrap | zsh
    else
        #There must be a better way to do this! (like make -C)
        current_dir=$PWD
        cd $vim_home
        rake default
        cd $current_dir
    fi
}

#create a backup directory
create_backup_dir()
{
    timestamp=`date "+%Y-%h-%d-%H-%M-%S"`
    backup_dir="$BACKUP_ROOT/$timestamp"
    mkdir -p $backup_dir
    if [ -d $backup_dir ]
    then
        BACKUP_DIR=$backup_dir
    else
        echo "     [x] Could not create backup directory $backup_dir"
        return 1
    fi
}

#backup a file
backup_file()
{
    backup_dir=$1/
    source_file=$2
    mv $source_file $backup_dir
}

#check dependencies and create backup directories
initialize()
{
    echo "     [+] Installing Homebrew and friends"
    install_homebrew
    echo "     [+] Installing pip and friends"
    install_pip
    install_janus
    create_backup_dir
}

#install the dot files in $HOME_DIR
install_dotfiles()
{

    # glob *.SYMLINK_EXT from directories and create equivalent symlinks in $HOME_DIR
    for f in `find $PWD -name "*.$SYMLINK_EXT"`; do
        target=$HOME_DIR/.`basename -s .$SYMLINK_EXT $f`

        #if the target exists then back it up
        if [ -e $target ]
        then
            backup_file $BACKUP_DIR $target
        fi

       ln -s $f $target;
    done
}

#unleash the dots!
initialize
if [ $? -eq 0 ]
then
    install_dotfiles
    echo "     [+] dotfile installation complete"
    echo "     [+] Your old dot files are backed up in $BACKUP_DIR"
    echo "     [+] You can revert the changes with revert.sh"
else
    echo "     [x] There was an error initializing... will revert changes now"
    source revert.sh
    echo "     [x] Done."
fi
