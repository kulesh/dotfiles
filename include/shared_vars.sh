#!/bin/sh

# Shared variables between install.sh and revert.sh
HOME_DIR=$HOME # Makes it easy to test
BACKUP_ROOT="$HOME_DIR/.dotbackup"
SYMLINK_EXT="sl" # Extension of files to symlink
