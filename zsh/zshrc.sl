#umask for homrbrew multiuser
umask 0002
export CLICOLOR=YES
export LSCOLORS="Gxfxcxdxbxegedabagacad"

#vcs info
autoload -Uz vcs_info

zstyle ':vcs_info:*' stagedstr '%F{28}●'
zstyle ':vcs_info:*' unstagedstr '%F{11}●'
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:(sv[nk]|bzr):*' branchformat '%b%F{1}:%F{11}%r'
zstyle ':vcs_info:*' enable git svn
precmd () {
  if [[ -z $(git ls-files --other --exclude-standard 2> /dev/null) ]] {
    zstyle ':vcs_info:*' formats ' [%F{green}%b%c%u%F{blue}]'
  } else {
    zstyle ':vcs_info:*' formats ' [%F{green}%b%c%u%F{red}●%F{blue}]'
  }

  vcs_info
}

setopt prompt_subst
PROMPT='%F{white}%n@%m %c${vcs_info_msg_0_}%F{white} %(?/%F{white}/%F{red})%% %{$reset_color%}'

# history
setopt histignorealldups sharehistory
HISTSIZE=1024
SAVEHIST=1024
HISTFILE=~/.zsh_history

#auto complete
autoload -Uz compinit
compinit -u
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
# zstyle ':completion:*' menu select=2 eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
#zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

alias retag='ctags -f ".tags" -R --totals --exclude=tmp --exclude=log --exclude=.git . $(bundle list --paths)'
eval "$(direnv hook zsh)"

## setup direnvwrapper
DIRENVWRAPPER_SOURCE=$DOTFILES/lib/direnvwrapper.sh
if [ -f $DIRENVWRAPPER_SOURCE ]
then
  source $DIRENVWRAPPER_SOURCE
fi

export FZF_DEFAULT_OPTS='--height 50% --reverse --border --inline-info'
export FZF_COMPLETION_TRIGGER='~~'
export FZF_DEFAULT_COMMAND='rg -g ""'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# Python virtual environment prompts
show_virtual_env() {
  if [[ -n "$VIRTUAL_ENV" && -n "$DIRENV_DIR" ]]; then
    echo "($(basename $VIRTUAL_ENV))"
  fi
}
PS1='$(show_virtual_env)'$PS1
