#!/usr/bin/env zsh
#MISE description="Install Python via mise"
#MISE dir="{{cwd}}"

mise use python@latest
mise use uv@latest

# Activate the project's .venv whenever you're in the project, so its
# ruff and basedpyright are on PATH for the shell, nvim, and agents.
cat >> .mise.toml <<'TOML'

[env]
_.python.venv = { path = ".venv", create = true }
TOML
mise install
