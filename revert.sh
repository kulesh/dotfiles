#!/bin/zsh

source include/shared_vars.sh

LATEST_BACKUP=''

#remove the symlinks in $HOME_DIR pointing to files in ~/.dotfiles/ (i.e $PWD)
remove_symlinked_files()
{
    for symlink in `find $HOME_DIR -name ".*" -type l -maxdepth 1`; do
        target=`readlink $symlink`
        target_dir=`dirname $target`
        target_ext=`basename $target|sed 's/.*\.//'`

        if [[ $target_dir == *$PWD* && $target_ext == $SYMLINK_EXT ]]
        then
            rm -f $symlink
        fi
    done
}

#restore files from the latest backup
restore_from_backup()
{
    if [ ! -e $BACKUP_ROOT ]
    then
        echo "     [-] There is no backup to revert to."
        return 1
    fi

    for f in `ls -tu $BACKUP_ROOT`; do
        latest_backup_dir=$BACKUP_ROOT/$f
        if [ "$(ls -A $latest_backup_dir)" ]
        then
            mv $latest_backup_dir/.* $HOME_DIR/ 2> /dev/null || true
        fi
        rmdir $latest_backup_dir
        LATEST_BACKUP=$f
        break #just process the latest backup
    done
    rmdir $BACKUP_ROOT 2> /dev/null || true #remove when it's empty
}

remove_symlinked_files
restore_from_backup
if [ $? -eq 0 ]
then
    echo "     [+] Successfully reverted to the dot files as of $LATEST_BACKUP"
fi
