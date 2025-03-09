#!/usr/bin/env zsh
set -e 

source include/shared_vars.sh

BACKUP_DIR='' # where we will backup this instance of install
INSTALL_SCRIPT_AT="${0:a:h}"

install_homebrew()
{
    if ! type "$brew" &> /dev/null; then
        echo "     [-] There is no Homebrew. Going to install Homebrew."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

		local BREWFILE_PATH="${INSTALL_SCRIPT_AT}/brew/Brewfile"
		# Verify Brewfile exists and is readable
		if [[ ! -f "$BREWFILE_PATH" ]]; then
				echo "Error: Brewfile not found at ${BREWFILE_PATH}" >&2
				exit 1
		fi

		if [[ ! -r "$BREWFILE_PATH" ]]; then
				echo "Error: Cannot read Brewfile at ${BREWFILE_PATH}" >&2
				echo "Please check file permissions" >&2
				exit 1
		fi

		# Install Homebrew packages
		echo "Installing packages from Brewfile..."
		if brew bundle --file="$BREWFILE_PATH"; then
				echo "✅ Homebrew packages installed successfully!"
			  brew bundle --file="$BREWFILE_PATH" cleanup
			  brew doctor
		else
				echo "⚠️Some Homebrew installations may have failed. Please check the output above."
				# We don't exit with error here to allow the script to continue with other setups
		fi
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
    echo "     [+] Installing CLI font"
    install_cli_font

    create_backup_dir
}

# install the dot files in $HOME_DIR
install_dotfiles()
{
	echo "🔗 Setting up dotfiles with stow..."
  
  # Check if stow is installed
  if ! command -v stow &> /dev/null; then
    echo "Error: stow is not installed"
    echo "Installing stow with Homebrew..."
    brew install stow
  fi
  
  # Change to the dotfiles directory (required for stow to work correctly)
  cd "$INSTALL_SCRIPT_AT"
  
  # List of packages to stow
  local packages="${STOWED_PACKAGES}"
  
  # Stow each package
  for package in "${packages[@]}"; do
    if [[ -d "$package" ]]; then
      echo "Stowing $package..."
      stow --verbose --target="$HOME_DIR" --restow "$package"
      
      if [[ $? -eq 0 ]]; then
        echo "✅ $package linked successfully"
      else
        echo "⚠️ Failed to stow $package"
      fi
    else
      echo "⚠️ Package directory $package not found, skipping..."
    fi
  done
  
  return 0
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
