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
