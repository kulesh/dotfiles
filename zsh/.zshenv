# Resolve dotfiles root: .zshenv → (symlink) → .dotfiles/zsh/.zshenv
# :A resolves symlinks, :h :h walks up zsh/ → dotfiles root
export DOTFILES_DIR="${${(%):-%x}:A:h:h}"

# Source shared variables
source "$DOTFILES_DIR/include/shared_vars.sh"

# XDG base directories
export XDG_CONFIG_HOME=$HOME_DIR/.config
export XDG_DATA_HOME=$HOME_DIR/.local/share
export XDG_CACHE_HOME=$HOME_DIR/.cache
export XDG_STATE_HOME=$HOME_DIR/.local/state

# Tool-specific paths
export DOTFILES=$HOME_DIR/.dotfiles
export PROJECTS=$PROJECT_DIR
export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml
export _ZO_DATA_DIR=$XDG_CONFIG_HOME/zoxide/

export HOMEBREW_AUTO_UPDATE_SECS=86400

umask 0002

# uv
export PATH="$HOME_DIR/.local/bin:$PATH"
