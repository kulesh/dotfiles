#!/usr/bin/env zsh
#MISE hide=true
# Helpers shared by the project:* tasks. Hidden from the task list;
# each task sources it.
#
# A project is a repo at ~/dev/<org>/<repo> with a mise config (.mise.toml
# or .tool-versions). An org is a GitHub user or organization: a cloned repo
# lives under its owner, a created one under your GitHub login. Each org
# directory is a mise monorepo (org_dir), so a task can run in all its repos.

projects_dir=$HOME/dev
templates_dir=${${(%):-%x}:A:h:h}/mkproject

typeset -gA c=(cyan $'\e[36m' green $'\e[32m' yellow $'\e[33m' magenta $'\e[35m'
               red $'\e[31m' dim $'\e[2m' bold $'\e[1m' reset $'\e[0m')

die() { print -r -- "$*" >&2; exit 1; }

# A required argument, or how to use the command. mise's own check would
# print four lines of ERROR instead.
need() {   # need <value> <usage>
    [[ -n $1 ]] || die "Usage: $2"
}

# A project picked with fzf, showproject beside the highlighted one, for a
# command run without a name. Outside a terminal, or without fzf, explains
# the usage instead. Prints nothing if the picker is cancelled.
pick_project() {   # pick_project <usage>
    [[ -t 0 ]] && command -v fzf >/dev/null || die "Usage: $1   (lsprojects lists them)"
    project_names | fzf --height=60% --reverse --prompt="${1%% *}> " \
        --preview="mise -C / run project:show --from ${(q)projects_dir}/{}" \
        --preview-window=right,60% || true
}

is_project() { [[ -e $1/.mise.toml || -e $1/.tool-versions ]]; }

# An org or repo name: one path segment, never hidden (.archive and .migrating
# are ours), so a name can't reach outside ~/dev or into its own parts.
valid_name() { [[ $1 =~ '^[A-Za-z0-9_][A-Za-z0-9_.-]*$' ]]; }

# An org directory's mise.toml makes it a monorepo root, never a project.
is_org() { [[ -f $1/mise.toml ]] && grep -q '^monorepo_root = true' "$1/mise.toml"; }

# The GitHub login gh uses here, in lowercase: the org for projects you
# create. gh keeps it in its own config, so this works offline.
own_org() {
    local login
    login=$(gh config get -h github.com user 2>/dev/null) || login=
    [[ -n $login ]] || login=$(gh api user --jq .login 2>/dev/null) || return 1
    [[ -n $login ]] || return 1
    print -r -- "${login:l}"
}

# ~/dev/<org>, made a mise monorepo the first time a project lands in it. An
# existing mise.toml is the org's own and stays as it is.
org_dir() {   # org_dir <org>
    local dir=$projects_dir/$1
    mkdir -p "$dir"
    [[ -e $dir/mise.toml ]] || cat > "$dir/mise.toml" <<EOF
# The $1 projects, one repo each, as a mise monorepo:
#   mise run '//...:test'     runs test in every $1 repo
#   mise run //<repo>:test    runs it in one, from anywhere in $1
# Tools and [env] here reach every $1 repo.
monorepo_root = true

[monorepo]
config_roots = ["*"]
EOF
    print -r -- "$dir"
}

# The project you're in. Within ~/dev it's the repo, ~/dev/<org>/<repo>: a
# config deeper inside is a package of the repo, not another project.
# Elsewhere, the nearest directory with a mise config. ~/dev, an org and ~
# don't count: their configs are layers projects inherit.
project_root() {
    local dir=${1:A} dev=${projects_dir:A}
    if [[ $dir == $dev || $dir == $dev/* ]]; then
        local -a parts=(${(s:/:)${dir#$dev}})
        (( $#parts >= 2 )) || return 1
        dir=$dev/$parts[1]/$parts[2]
        is_project "$dir" || return 1
        print -r -- "$dir"
        return
    fi
    until is_project "$dir"; do
        [[ $dir == / ]] && return 1
        dir=${dir:h}
    done
    [[ $dir != ${HOME:A} ]] || return 1
    print -r -- "$dir"
}

# How a project is named: org/repo in ~/dev, the directory name elsewhere.
project_label() {
    local dev=${projects_dir:A}
    if [[ ${1:A} == $dev/*/* ]]; then print -r -- "${1:A:h:t}/${1:A:t}"; else print -r -- "${1:t}"; fi
}

# Every project in ~/dev, as org/repo. .archive is hidden, so never listed.
project_names() {
    local dir
    for dir in $projects_dir/*/*(N/); do is_project "$dir" && print -r -- "${dir:h:t}/${dir:t}"; done
}

# Names to complete: a repo name alone while one org has it, org/repo when
# more than one does.
project_short_names() {
    local -a names=(${(f)"$(project_names)"})
    local -A count
    local name
    for name in $names; do count[${name#*/}]=$(( ${count[${name#*/}]:-0} + 1 )); done
    for name in $names; do
        if (( count[${name#*/}] == 1 )); then print -r -- "${name#*/}"; else print -r -- "$name"; fi
    done
}

# A project directory from org/repo, or from a repo name only one org has;
# otherwise a clear error.
project_dir() {
    local dir
    if [[ $1 == */* ]]; then
        valid_name "${1%%/*}" && valid_name "${1#*/}" || die "Not a project name: $1 (use <org>/<repo>)"
        dir=$projects_dir/${${1%%/*}:l}/${1#*/}
    else
        valid_name "$1" || die "Not a project name: $1"
        local -a found=()
        for dir in $projects_dir/*/$1(N/); do is_project "$dir" && found+=("$dir"); done
        (( $#found > 1 )) && die "'$1' is in more than one org: ${(j:, :)${found[@]/#$projects_dir\//}}. Name one as <org>/$1."
        dir=${found[1]:-$projects_dir/$1}
    fi
    [[ -d $dir && ${dir:A} == ${projects_dir:A}/*/* ]] || die "No project '$1' in $projects_dir"
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

# What a user types for a GitHub repo → "clone URL|owner/repo". Accepts
# user/repo, gh user/repo, and HTTPS or SSH URLs; clones always use SSH.
parse_github_repo() {
    local spec=$1
    [[ $1 == gh && -n ${2:-} ]] && spec=$2
    local user repo
    if [[ $spec =~ '^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$' ]]; then
        user=${match[1]} repo=${match[2]%.git}
    elif [[ $spec =~ '^https://github\.com/([^/]+)/([^/]+)/?$' ]]; then
        user=${match[1]} repo=${match[2]%.git}
    elif [[ $spec =~ '^git@github\.com:([^/]+)/([^/]+)$' ]]; then
        user=${match[1]} repo=${match[2]%.git}
    else
        return 1
    fi
    print -r -- "git@github.com:$user/$repo.git|$user/$repo"
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

# AGENTS.md for a new project: the shared header, then the template's part
# (base's when the template has none). Claude Code reads AGENTS.md when a
# project has no CLAUDE.md, so one file serves every agent.
write_agent_docs() {   # write_agent_docs <project dir> <template> <project name>
    local header=$templates_dir/_shared/AGENTS.header.md
    local part=$templates_dir/$2/AGENTS.project.md
    [[ -f $part ]] || part=$templates_dir/base/AGENTS.project.md
    [[ -f $header && -f $part ]] || return 1
    cat "$header" "$part" > "$1/AGENTS.md" || return 1
    apply_placeholders "$1/AGENTS.md" "$3"
}
