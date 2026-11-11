#!/usr/bin/env zsh
#MISE hide=true
#MISE description="Install Ruby via mise"
#MISE dir="{{cwd}}"

set -eo pipefail   # a failed step stops the template; mkproject reports it

mise use ruby
mise install
