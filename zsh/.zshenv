# DOTFILES_DIR_PLACEHOLDER

# Source shared variables
source "$DOTFILES_DIR/include/shared_vars.sh"

#default location of things
<<<<<<< Updated upstream
export XDG_CONFIG_HOME=$HOME_DIR/.config
export STARSHIP_CONFIG=$HOME_DIR/.config/starship/starship.toml
export DOTFILES=$HOME_DIR/.dotfiles
export PROJECTS=$PROJECT_DIR

export XDG_CONFIG_HOME=$HOME_DIR/.config
export XDG_DATA_HOME=$HOME_DIR/.local/share
export XDG_CACHE_HOME=$HOME_DIR/.cache
export XDG_STATE_HOME=$HOME_DIR/.local/state

export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml

export HOMEBREW_AUTO_UPDATE_SECS=86400

umask 0002
