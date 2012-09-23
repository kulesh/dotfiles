#!/bin/sh

#shared variables between install.sh and revert.sh
HOME_DIR=$HOME #makes it easy to test
BACKUP_ROOT="$HOME_DIR/.dotbackup"
SYMLINK_EXT="sl" #extension of files to symlink
