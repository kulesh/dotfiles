#!/usr/bin/env zsh
# reload.zsh — a shell that keeps up with its own config.
#
# A shell reads its config once, when it starts. When a file it loaded
# changes (dsync, a git pull, an edit), it reloads itself before its next
# prompt, in every open window. exec keeps the directory, the process and
# the exported environment; it drops what was set only in this shell.

zmodload -F zsh/stat b:zstat
autoload -Uz add-zsh-hook

# The files this shell loaded, with their modification times, in REPLY.
# No subshell: it runs before every prompt.
_dotfiles_shell_signature() {
    local -a files=(
        ~/.zshenv(N) ~/.zshrc(N)
        $DOTFILES/lib/*(N.) $DOTFILES/include/*(N.)
        ${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml(N)
    )
    local -a mtimes
    zstat -A mtimes +mtime -- $files 2>/dev/null
    REPLY="${files[*]} ${mtimes[*]}"
}

_dotfiles_reload() {
    print -P "%F{243}Shell config changed; reloading.%f"
    if [[ -o login ]]; then exec "${SHELL:-zsh}" -l; else exec "${SHELL:-zsh}"; fi
}

_dotfiles_reload_if_changed() {
    _dotfiles_shell_signature
    [[ $REPLY == $_dotfiles_loaded ]] && return
    # Recorded first: if exec fails, the shell says so once, not every prompt.
    _dotfiles_loaded=$REPLY
    _dotfiles_reload
}

_dotfiles_shell_signature
typeset -g _dotfiles_loaded=$REPLY
add-zsh-hook precmd _dotfiles_reload_if_changed
