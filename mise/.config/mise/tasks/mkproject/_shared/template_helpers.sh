#!/usr/bin/env zsh
#MISE hide=true

# The mkproject directory, found from this file. Not from $0: inside a
# function, zsh sets $0 to the function's name.
_templates_dir=${${(%):-%x}:A:h:h}

# Copy template static files into the current project directory.
# Usage: copy_template_files <template_name> [label]
copy_template_files() {
    local template_name="$1"
    local label="${2:-$template_name}"

    if [[ -z "$template_name" ]]; then
        echo "❌ Error: copy_template_files requires a template name" >&2
        return 1
    fi

    local template_dir="${_templates_dir}/${template_name}/files"
    if [[ -d "$template_dir" ]]; then
        echo "Copying ${label} template files..."
        cp -r "$template_dir"/. "$PWD/"
    fi
}
