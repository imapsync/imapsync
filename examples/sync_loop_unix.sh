#!/bin/sh
#
# $Id: sync_loop_unix.sh,v 1.2 2012/12/23 08:02:46 gilles Exp gilles $

# Example for imapsync massive migration on Unix systems.
# 
# Data is supposed to be in file.txt in the following format
#user001_1;password001_1;user001_2;password001_2
#...
# Separator is character semi-colon ; it can be changed by any character changing IFS=';'
# Each data line contains 4 columns, columns are parameters for --user1 --password1 --user2 --password2
#
# Replace "imap.side1.org" and "imap.side2.org" with your own hostname values

# This loop will also create a log file called LOG/log_${u2}_$NOW.txt for each account transfer
# where u2 is just a variable containing the user2 account name, and NOW is the current date_time

mkdir -p LOG

{ while IFS=';' read  u1 p1 u2 p2
    do 
         { echo "$u1" | egrep "^#" ; } > /dev/null && continue
         NOW=`date +%Y_%m_%d_%H_%M_%S` 
         echo syncing to user "$u2"
         imapsync --host1 imap.side1.org --user1 "$u1" --password1 "$p1" \
                  --host2 imap.side2.org --user2 "$u2" --password2 "$p2" \
                  > LOG/log_${u2}_$NOW.txt 2>&1
    done 
} < file.txt

