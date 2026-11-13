#!/usr/bin/env zsh
# sandbox.sh — enter and leave the per-project macOS sandbox (workon -s)
#
# A project with a .sandbox marker opens a sandboxed shell inside this one,
# whenever this shell arrives there (chpwd, or a terminal opening there). The
# sandboxed shell ends when you leave the project or type exit:
#
#   outer shell ──cd project──▶ sandbox-exec zsh ──cd elsewhere──▶ outer shell
#                                     │                            goes there too
#                                     └──exit──▶ outer shell closes too
#
# The two shells talk through one file the outer shell makes and passes in
# ($SANDBOX_EXIT_FILE): the sandboxed shell writes "entered" when it starts,
# and the directory it left for, if it left. Empty means it never started.

typeset -g SANDBOX_PROFILE=${XDG_CONFIG_HOME:-$HOME/.config}/sandbox/profiles/default.sb
typeset -g SANDBOX_LOG_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/sandbox/logs

# workon -s writes the marker; it alone decides.
_sandbox_is_project() { [[ -f $1/.sandbox ]]; }

_sandbox_log() {   # _sandbox_log <project> <event> <message>; never fails
    mkdir -p "$SANDBOX_LOG_DIR" 2>/dev/null || return 0
    print -r -- "$(date -u +%Y-%m-%dT%H:%M:%SZ) [$2] $3" >> "$SANDBOX_LOG_DIR/$1.log" 2>/dev/null
}

if [[ -z $IN_SANDBOX ]]; then
    # Run the project's sandboxed shell, then follow it: to where it left for,
    # or close this shell too if you exited it. If it can't start, say why
    # and stay here.
    _workon_sandboxed() {   # _workon_sandboxed <project dir>
        local dir=$1 name=${1:t}
        [[ -f $SANDBOX_PROFILE ]] || { print -r -- "Sandbox profile not found: $SANDBOX_PROFILE; staying unsandboxed" >&2; return 1; }
        local exit_file
        exit_file=$(mktemp "${TMPDIR:-/tmp}/sandbox-exit.XXXXXX") || return 1

        _sandbox_log "$name" ENTER "pid=$$ dir=$dir"
        print -P "%B%F{green}▸ sandbox entered%f%b: %F{cyan}[$name]%f"
        print -P "  %F{8}project%f  $dir"
        print -P "  %F{8}network%f  outbound allowed"

        _SANDBOX_SPAWNING=1   # this cd mustn't start another sandbox
        builtin cd -- "$dir"
        sandbox-exec -f "$SANDBOX_PROFILE" \
            -D "HOME=$HOME" -D "PROJECT=$dir" -D "SSH_REAL=${${:-$HOME/.ssh}:A}" \
            env TERM="$TERM" IN_SANDBOX=1 SANDBOX_PROJECT="$name" SANDBOX_PROJECT_DIR="$dir" \
                SANDBOX_EXIT_FILE="$exit_file" /bin/zsh -i
        local code=$? said=$(<"$exit_file")
        rm -f "$exit_file"
        unset _SANDBOX_SPAWNING

        print -P "%B%F{red}▸ sandbox exited%f%b: %F{cyan}[$name]%f"
        case $said in
            '')
                _sandbox_log "$name" EXIT "pid=$$ never started ($code)"
                print -r -- "The sandbox didn't start (sandbox-exec exited $code); staying unsandboxed" >&2
                return 1 ;;
            entered)
                _sandbox_log "$name" EXIT "pid=$$ exit ($code)"
                exit $code ;;
            *)
                _sandbox_log "$name" EXIT "pid=$$ left for $said"
                cd -- "$said" ;;   # into another sandboxed project: its sandbox starts
        esac
    }

    _sandbox_entry_chpwd() {
        [[ -z $_SANDBOX_SPAWNING ]] && _sandbox_is_project "$PWD" && _workon_sandboxed "$PWD"
        return 0
    }
    chpwd_functions+=(_sandbox_entry_chpwd)

    # A terminal that opens in a sandboxed project starts there without a cd.
    _sandbox_entry_chpwd
else
    # Inside the sandbox: tell the outer shell this one started, and where it
    # went when it leaves the project.
    [[ -n $SANDBOX_EXIT_FILE ]] && print entered > "$SANDBOX_EXIT_FILE"
    _sandbox_chpwd() {
        if [[ $PWD != $SANDBOX_PROJECT_DIR && $PWD != $SANDBOX_PROJECT_DIR/* ]]; then
            print -r -- "$PWD" > "$SANDBOX_EXIT_FILE"
            exit
        fi
    }
    chpwd_functions+=(_sandbox_chpwd)
fi
