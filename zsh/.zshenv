# Resolve dotfiles root: .zshenv → (symlink) → .dotfiles/zsh/.zshenv
# :A resolves symlinks, :h :h walks up zsh/ → dotfiles root
export DOTFILES_DIR="${${(%):-%x}:A:h:h}"

# Source shared variables
source "$DOTFILES_DIR/include/shared_vars.sh"

# XDG base directories
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CACHE_HOME=$HOME/.cache
export XDG_STATE_HOME=$HOME/.local/state

# Tool-specific paths
export DOTFILES=$HOME/.dotfiles
export PROJECTS=$PROJECT_DIR
export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml
export _ZO_DATA_DIR=$XDG_CONFIG_HOME/zoxide/

export HOMEBREW_AUTO_UPDATE_SECS=86400

# uv
export PATH="$HOME/.local/bin:$PATH"
