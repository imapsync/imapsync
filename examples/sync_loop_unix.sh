#!/bin/sh
#
# $Id: sync_loop_unix.sh,v 1.4 2014/05/22 14:22:15 gilles Exp gilles $

# Example for imapsync massive migration on Unix systems.
# 
# Data is supposed to be in file.txt in the following format
# user001_1;password001_1;user001_2;password001_2
# ...
# Separator is character semi-colon ";" it can be changed by any character changing IFS=';' 
# in the while loop below.
# Each data line contains 4 columns, columns are parameters for --user1 --password1 --user2 --password2
#
# For Mac users you may have to add a fake fifth element in file.txt to avoid that a CR character
# goes in the p2 variable. Change also the read command to "read u1 p1 u2 p2 fake".
# 
# Replace "imap.side1.org" and "imap.side2.org" with your own hostname values.
# You can add extra options after --password2 "$p2"
# Use character backslash \ at the end of each suplementary line, exept for the last one.

echo Looping on account credentials found in file.txt
echo

{ while IFS=';' read  u1 p1 u2 p2
    do 
        { echo "$u1" | egrep "^#" ; } > /dev/null && continue # this skip commented lines in file.txt
        echo "==== Syncing user $u1 to user $u2 ===="
        imapsync --host1 imap.side1.org --user1 "$u1" --password1 "$p1" \
                 --host2 imap.side2.org --user2 "$u2" --password2 "$p2"
        
        echo "==== End syncing user $u1 to user $u2 ===="
        echo
    done 
} < file.txt

