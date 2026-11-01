#!/usr/bin/env zsh
#MISE hide=true
# Helpers shared by the project:* tasks. Hidden from the task list;
# each task sources it.
#
# A project is a directory in ~/dev with a mise config (.mise.toml or
# .tool-versions). Cloned projects have a GitHub origin; created ones don't.

projects_dir=$HOME/dev
templates_dir=${${(%):-%x}:A:h:h}/mkproject

typeset -gA c=(cyan $'\e[36m' green $'\e[32m' yellow $'\e[33m' magenta $'\e[35m'
               red $'\e[31m' dim $'\e[2m' bold $'\e[1m' reset $'\e[0m')

die() { print -r -- "$*" >&2; exit 1; }

is_project() { [[ -e $1/.mise.toml || -e $1/.tool-versions ]]; }

# The nearest directory at or above $1 with a mise config.
project_root() {
    local dir=${1:A}
    until is_project "$dir"; do
        [[ $dir == / ]] && return 1
        dir=${dir:h}
    done
    print -r -- "$dir"
}

# Every project in ~/dev, by name.
project_names() {
    local dir
    for dir in $projects_dir/*(N/); do is_project "$dir" && print -r -- "${dir:t}"; done
}

# A project directory by name, or a clear error.
project_dir() {
    local dir=$projects_dir/$1
    [[ -d $dir ]] || die "No project '$1' in $projects_dir"
    is_project "$dir" || die "$dir isn't a project (no .mise.toml)"
    print -r -- "$dir"
}

# user/repo for a project cloned from GitHub; fails for anything else.
github_slug() {
    local url
    # The URL as configured, not as rewritten by url.insteadOf.
    url=$(git -C "$1" config --get remote.origin.url 2>/dev/null) || return 1
    [[ $url =~ 'github\.com[:/]([^/]+)/([^/]+)$' ]] || return 1
    print -r -- "${match[1]}/${match[2]%.git}"
}

# What a user types for a GitHub repo → "clone URL|project name". Accepts
# user/repo, gh user/repo, and HTTPS or SSH URLs; clones always use SSH.
parse_github_repo() {
    local spec=$1
    [[ $1 == gh && -n ${2:-} ]] && spec=$2
    local user repo
    if [[ $spec =~ '^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$' ]]; then
        user=${match[1]} repo=${match[2]}
    elif [[ $spec =~ '^https://github\.com/([^/]+)/([^/]+)/?$' ]]; then
        user=${match[1]} repo=${match[2]%.git}
    elif [[ $spec =~ '^git@github\.com:([^/]+)/([^/]+)$' ]]; then
        user=${match[1]} repo=${match[2]%.git}
    else
        return 1
    fi
    print -r -- "git@github.com:$user/$repo.git|$repo"
}

last_modified() {
    if [[ $OSTYPE == darwin* ]]; then
        stat -f %Sm -t "${2:-%b %d}" "$1" 2>/dev/null
    else
        date -d "@$(stat -c %Y "$1")" +"${2:-%b %d}" 2>/dev/null
    fi
}

# Tasks can't change the directory of the shell that ran them. Leave the
# destination for the shell to pick up at its next prompt (lib/follow.zsh);
# without one, say where to go.
follow() {
    if [[ -n ${DOTFILES_FOLLOW:-} ]]; then
        mkdir -p "${DOTFILES_FOLLOW:h}"
        print -r -- "$1" > "$DOTFILES_FOLLOW"
    else
        print -r -- "cd $1"
    fi
}

# Ask y/n on the terminal, Enter taking the default. Without a terminal the
# command was asked for explicitly (a script, a test), so go ahead.
confirm() {   # confirm <question> <y|n default>
    [[ -t 0 ]] || return 0
    local reply
    read -r "reply?$1 " || return 1
    [[ -z $reply ]] && reply=$2
    [[ $reply == [yY]* ]]
}

# =============================================================================
# Agent docs: CLAUDE.md and AGENTS.md from a shared header plus the
# template's own part, with the project's name filled in
# =============================================================================

escape_sed() {
    local value=${1//\\/\\\\}
    print -r -- "${value//&/\\&}"
}

apply_placeholders() {   # apply_placeholders <file> <project name>
    [[ -f $1 ]] || return 0
    local name=$(escape_sed "$2") module=$(escape_sed "${2//-/_}")
    sed -i.bak -e "s|<project-name>|$name|g" -e "s|<project_name>|$name|g" \
        -e "s|<module_name>|$module|g" "$1" && rm -f "$1.bak"
}

write_agent_docs() {   # write_agent_docs <project dir> <template> <project name>
    local shared=$templates_dir/_shared own=$templates_dir/$2 base=$templates_dir/base
    local claude=$own/CLAUDE.project.md agents=$own/AGENTS.project.md
    [[ -f $claude ]] || claude=$base/CLAUDE.project.md
    [[ -f $agents ]] || agents=$claude
    [[ -f $shared/CLAUDE.header.md && -f $claude ]] || return 1
    cat "$shared/CLAUDE.header.md" "$claude" > "$1/CLAUDE.md" &&
        cat "$shared/AGENTS.header.md" "$agents" > "$1/AGENTS.md" || return 1
    apply_placeholders "$1/CLAUDE.md" "$3"
    apply_placeholders "$1/AGENTS.md" "$3"
}
