#!/usr/bin/env zsh
#MISE description="Install Python via mise"
#MISE dir="{{cwd}}"

mise use python@latest
mise use uv@latest
mise install
