# The dotfiles checkout, wherever it is: ~/.zshenv links to <checkout>/zsh/.zshenv,
# so resolve this file (:A) and walk up two directories (:h:h).
export DOTFILES=${${(%):-%x}:A:h:h}

source "$DOTFILES/include/shared_vars.sh"

# XDG base directories
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CACHE_HOME=$HOME/.cache
export XDG_STATE_HOME=$HOME/.local/state

# Tool-specific paths
export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml
export _ZO_DATA_DIR=$XDG_CONFIG_HOME/zoxide/

export HOMEBREW_AUTO_UPDATE_SECS=86400

# uv
# Each directory once: the shell reloads itself (lib/reload.zsh), and every
# reload would otherwise prepend the same directories again. -U holds for
# assignments to the path array, not to the PATH string.
typeset -U path
path=($HOME/.local/bin $path)
