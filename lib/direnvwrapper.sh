#!/bin/zsh

workon() {
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
  if [ "$#" -ne 1 ]
  then
    echo "$0 - Creates a direnv project"
    echo "Usage: $0 project_name"
    return
  fi

  project_dir=$PROJECTS/$1
  if [ -d $project_dir ]
  then
    echo "Project already exists in $project_dir"
    return -1
  else
    mkdir $project_dir
    cd $project_dir
  fi
}
