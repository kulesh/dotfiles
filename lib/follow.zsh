#!/usr/bin/env zsh
# follow.zsh — let commands move the shell.
#
# The project commands are mise tasks, child processes that can't change
# this shell's directory. A task that wants the shell somewhere (workon,
# mkproject, cloneproject, cdproject, rmproject) writes the directory to
# $DOTFILES_FOLLOW, and before the next prompt the shell goes there.

export DOTFILES_FOLLOW=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/follow.$$
mkdir -p "${DOTFILES_FOLLOW:h}"

_dotfiles_follow() {
    [[ -s $DOTFILES_FOLLOW ]] || return 0
    local dir=$(<"$DOTFILES_FOLLOW")
    rm -f "$DOTFILES_FOLLOW"
    builtin cd -- "$dir"   # not zoxide's cd: this is an exact path
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _dotfiles_follow
add-zsh-hook zshexit _dotfiles_follow_cleanup
_dotfiles_follow_cleanup() { rm -f "$DOTFILES_FOLLOW"; }
