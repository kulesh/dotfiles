#!/bin/zsh
source include/shared_vars.sh

BREWED_TOOLS=(python python3 golang rbenv ruby-build tree aspell --lang=en direnv fzf highlight)
RUBY_GEMS=(bundler foreman)
BACKUP_DIR='' # where we will backup this instance of install

install_homebrew()
{
    if ! type "$brew" &> /dev/null; then
        echo "     [-] There is no Homebrew. Going to install Homebrew."
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi

    brew update
    brew upgrade
    brew install $BREWED_TOOLS
    brew tap universal-ctags/universal-ctags
    brew install --HEAD universal-ctags
    brew tap burntsushi/ripgrep https://github.com/BurntSushi/ripgrep.git
    brew install burntsushi/ripgrep/ripgrep-bin

    /usr/local/opt/fzf/install --all
}

# Install system-wide Ruby Gems
install_rubygems()
{
    if ! type "$gem" &> /dev/null; then
      echo "     [-] There is no Gem. You need to install Ruby. (brew install ruby)"
    else
      gem update --system
      gem install $RUBY_GEMS --no-rdoc --no-ri
    fi
}

install_janus()
{
    vim_home=$HOME/.vim
    janus_plugin_dir=$HOME/.janus
    if [ ! -d $vim_home/janus ]
    then
        curl -Lo- https://bit.ly/janus-bootstrap | sh
    else
        # There must be a better way to do this! (like make -C)
        # bundle exec rake default -f $vim_home
        cd $vim_home
        rake default
        cd -
    fi

    # install plugins
    mkdir -p $janus_plugin_dir
    git clone git@github.com:junegunn/fzf.vim.git $janus_plugin_dir/fzf
    git clone git@github.com:vim-airline/vim-airline.git $janus_plugin_dir/vim-airline
    git clone git@github.com:tpope/vim-rails.git $janus_plugin_dir/vim-rails
}

install_cli_font()
{
    # Using Inconsolata http://www.levien.com/type/myfonts/inconsolata.html
    font_source=http://www.levien.com/type/myfonts/Inconsolata.otf
    font_target=$HOME_DIR/Library/Fonts/Inconsolata.otf

    if [ ! -f $font_target ]
    then
        curl -L $font_source -o $font_target
    fi
}

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

backup_file()
{
    backup_dir=$1/
    source_file=$2
    mv $source_file $backup_dir
}

# check dependencies and create backup directories
initialize()
{
    echo "     [+] Installing Homebrew and friends"
    install_homebrew
    echo "     [+] Installing pip and friends"
    install_pip
    echo "     [+] Installing Ruby Gems"
    install_rubygems
    echo "     [+] Installing Janus for vim"
    install_janus
    echo "     [+] Installing CLI font"
    install_cli_font

    create_backup_dir
}

# install the dot files in $HOME_DIR
install_dotfiles()
{

    # glob *.SYMLINK_EXT from directories and create equivalent symlinks in $HOME_DIR
    for f in `find $PWD -name "*.$SYMLINK_EXT"`; do
        target=$HOME_DIR/.`basename -s .$SYMLINK_EXT $f`

        # if the target exists then back it up
        if [ -e $target ]
        then
            backup_file $BACKUP_DIR $target
        fi

       ln -s $f $target;
    done
}

# Unleash the dots!
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
