# remap to familiar screen keys
set -g prefix 'C-\'
unbind C-b
bind 'C-\' send-prefix

# force a reload of the config file
unbind r
bind r source-file ~/.tmux.conf

# quick pane cycling
unbind ^A
bind ^A select-pane -t :.+

# pane sizing
bind u resize-pane -U 10
bind d resize-pane -D 10
bind l resize-pane -L 10
bind r resize-pane -R 10

# chroma and scrolling
set -g default-terminal "screen-256color"
set -g mouse on
# set -g mouse-select-pane on
# bind-key -t vi-copy WheelUpPane scroll-up
# bind-key -t vi-copy WheelDownPane scroll-down

# direnv subshell mangling
set-option -g update-environment "DIRENV_DIFF DIRENV_DIR DIRENV_WATCHES"
set-environment -gu DIRENV_DIFF
set-environment -gu DIRENV_DIR
set-environment -gu DIRENV_WATCHES
set-environment -gu DIRENV_LAYOUT

source-file "${DOTFILES}/tmux/tmux-themepack/powerline/double/cyan.tmuxtheme"
