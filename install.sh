#!/usr/bin/env zsh
set -e 

source include/shared_vars.sh

BACKUP_DIR='' # where we will backup this instance of install
INSTALL_SCRIPT_AT="${0:a:h}"

install_homebrew()
{
    if ! command -v brew &> /dev/null; then
        echo "     [-] There is no Homebrew. Going to install Homebrew."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Determine the correct Homebrew path based on architecture
        if [[ $(uname -m) == "arm64" ]]; then
            # M1/M2 Mac
            BREW_PATH="/opt/homebrew/bin/brew"
        else
            # Intel Mac
            BREW_PATH="/usr/local/bin/brew"
        fi
        
        # Check if Homebrew was installed and set the PATH for this session
        if [[ -f "$BREW_PATH" ]]; then
            echo "     [-] Homebrew installed. Initializing Homebrew in current shell..."
            eval "$($BREW_PATH shellenv)"
        else
            echo "     [x] Homebrew installation may have failed. Brew executable not found."
            return 1
        fi
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

# ssh keys for GitHub
generate_ssh_keys() {
  echo "🔑 Setting up SSH keys for GitHub..."
 
  # Default location for SSH keys
  local ssh_dir="$HOME_DIR/.ssh"
  local key_file="$ssh_dir/id_ed25519"
  local pub_file="$key_file.pub"
 
  # Create SSH directory if it doesn't exist
  if [[ ! -d "$ssh_dir" ]]; then
    echo "Creating SSH directory..."
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
  fi
 
  # Check if keys already exist
  if [[ -f "$key_file" ]]; then
    echo "SSH key already exists at $key_file"
    read -q "REPLY?Do you want to generate a new key anyway? (y/n) "
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
      echo "Keeping existing SSH key."
      return 0
    fi
    # Backup existing key
    local backup_key="$key_file.backup-$(date +%Y%m%d%H%M%S)"
    echo "Backing up existing SSH key to $backup_key"
    cp "$key_file" "$backup_key"
    cp "$pub_file" "$backup_key.pub"
  fi
 
  # Get user input for key
  echo "Generating new SSH key for GitHub..."
  read "email?Enter your GitHub email: "
 
  # Generate the key
  ssh-keygen -t ed25519 -C "$email" -f "$key_file"
 
  # Start ssh-agent and add the key
  eval "$(ssh-agent -s)"
  ssh-add "$key_file"
 
  # Copy public key to clipboard
  if command -v pbcopy &> /dev/null; then
    # macOS
    pbcopy < "$pub_file"
    echo "Public key copied to clipboard!"
  else
    echo "Your public key is:"
    cat "$pub_file"
    echo "Please copy it manually."
  fi
 
  # Ask user to add key to GitHub
  echo ""
  echo "Please add this key to your GitHub account:"
  echo "1. Go to GitHub.com → Settings → SSH and GPG keys → New SSH key"
  echo "2. Paste the key (it's already in your clipboard on macOS)"
  echo "3. Give it a title (e.g., $(hostname))"
  echo ""
  read -q "REPLY?Press Y when you've added the key to GitHub (y/n) "
  echo ""
 
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Test the connection
    echo "Testing GitHub SSH connection..."
    if ssh -T git@github.com -o StrictHostKeyChecking=accept-new; then
      echo "✅ SSH connection to GitHub successful!"
    else
      echo "⚠️ SSH connection test returned a non-zero exit code."
      echo "   This may be normal if GitHub printed the welcome message."
      echo "   If you're unsure, please check your SSH connection manually."
    fi
  else
    echo "Skipping GitHub connection test."
  fi
 
  # Set git config if email was provided
  if [[ -n "$email" ]]; then
    echo "Would you like to set this email in your git config? (y/n)"
    read -q "REPLY?"
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      read "name?Enter your name for git config: "
      git config --global user.email "$email"
      git config --global user.name "$name"
      echo "✅ Git config updated with your name and email!"
    fi
  fi
 
  echo "🔑 SSH key setup complete!"
  return 0
}

# Unleash the dots!
initialize
if [ $? -eq 0 ]
then
 		install_dotfiles
		generate_ssh_keys
    echo "     [+] dotfile installation complete"
    echo "     [+] Your old dot files are backed up in $BACKUP_DIR"
    echo "     [+] You can revert the changes with revert.sh"
else
    echo "     [x] There was an error initializing... will revert changes now"
    source revert.sh
    echo "     [x] Done."
fi
