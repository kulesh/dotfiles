# DOTFILES_DIR_PLACEHOLDER

# Source shared variables
source "$DOTFILES_DIR/include/shared_vars.sh"

#default location of things
export XDG_CONFIG_HOME=$HOME_DIR/.config
export STARSHIP_CONFIG=$HOME_DIR/.config/starship/starship.toml
export DOTFILES=$HOME_DIR/.dotfiles
export PROJECTS=$PROJECT_DIR

export HOMEBREW_AUTO_UPDATE_SECS=86400

umask 0002
