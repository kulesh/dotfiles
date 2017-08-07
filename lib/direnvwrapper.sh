#!/bin/zsh

DIRENV_PROJECT_FILE=".project"

cdproject() {
  if [ -z $DIRENV_DIR ]
  then
    cd $HOME
    return
  fi

  direnv_dir=${DIRENV_DIR#-}
  project_file=$direnv_dir/$DIRENV_PROJECT_FILE
  if [ -e $project_file ]
  then
    cd `cat $project_file`
    return
  fi

  cd $direnv_dir
}

setprojecthome() {
  if [ -z $DIRENV_DIR ]
  then
    echo "You must be in a project to use this."
    return
  fi

  project_home="$(pwd)"
  direnv_dir=${DIRENV_DIR#-}
  project_file=$DIRENV_PROJECT_FILE

  echo "Setting project home to $project_home"
  echo "$project_home" > "$direnv_dir/$project_file"
}

workon() {
  __is_project_setup
  if [ "$?" -ne 0 ]
  then
    return
  fi

  if [ "$#" -ne 1 ]
  then
    for directory in `ls -d $PROJECTS/*`; do
      echo "${directory##*/}"
    done
    return
  fi

  project_dir=$PROJECTS/$1
  if [ -d $project_dir ]
  then
    cd $project_dir
  else
    echo "No such project exists!"
    return -1
  fi
}

mkproject() {
  if [[ "$#" -lt 1 || "$#" -gt 2 ]]
  then
    echo "$0 - Creates a direnv project"
    echo "Usage: $0 project_name [language]"
    return
  fi

  project_dir=$PROJECTS/$1
  if [ -d $project_dir ]
  then
    echo "Project $1 already exists in $project_dir"
    return -1
  fi

  mkdir -p $project_dir

  envrc_template_dir=$DOTFILES/direnv/envrc/
  envrc_template_file=envrc
  if [ "$#" -eq 2 ]
  then
    envrc_template_dir=${envrc_template_dir}$2"/"
  fi
  envrc_source=${envrc_template_dir}${envrc_template_file}
  envrc_target=${project_dir}"/.envrc"
  cp $envrc_source $envrc_target
  direnv allow $envrc_target
  cd $project_dir
}

__is_project_setup() {
  if [[ ! -d $PROJECTS ]]
  then
    echo "Use mkproject to make projects first"
    return -1
  fi

  return 0
}

list_projects() {
  for directory in `ls -d $PROJECTS/*`; do
    echo "${directory##*/}"
  done
}

_list_projects() {
  reply=( $(list_projects) )
}

#setup tab completion
compctl -K _list_projects workon
