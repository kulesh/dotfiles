# Usage: layout pyvenv [python_version]
# Example: layout pyvenv python3.7
#
# Use Python 3 venv module whenever it is available
#
layout_pyvenv() {
    local python=${1:-python3}
    [[ $# -gt 0 ]] && shift
    unset PYTHONHOME
    if [[ -n $VIRTUAL_ENV ]]; then
        VIRTUAL_ENV=$(realpath "${VIRTUAL_ENV}")
    else
        local python_version
        python_version=$("$python" -c "import platform; print(platform.python_version())")
        if [[ -z $python_version ]]; then
            log_error "Could not detect Python version"
            return 1
        fi
        VIRTUAL_ENV=$PWD/.direnv/python-venv-$python_version
    fi
    export VIRTUAL_ENV
    if [[ ! -d $VIRTUAL_ENV ]]; then
        log_status "no venv found; creating $VIRTUAL_ENV"
        "$python" -m venv "$VIRTUAL_ENV"
    fi
    PATH_add "$VIRTUAL_ENV/bin"
}


# Usage: layout gb
#
# Sets up environment for a Go project using the alternative gb build tool. In
# addition to project executables on PATH, this includes an exclusive, project-
# local GOPATH which enables many tools like gocode and oracle to "just work".
#
# http://getgb.io/
#
layout_gb() {
  export GOPATH="$PWD/vendor:$PWD"
  PATH_add "$PWD/vendor/bin"
  PATH_add bin
}
