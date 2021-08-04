#!/bin/sh
#
# $Id: sync_loop_unix.sh,v 1.10 2020/12/11 18:09:11 gilles Exp gilles $

# Example for imapsync massive migration on Unix systems.
# See also http://imapsync.lamiral.info/FAQ.d/FAQ.Massive.txt
#
# Data is supposed to be in file.txt in the following format:
# host001_1;user001_1;password001_1;host001_2;user001_2;password001_2;
# ...
# Separator is character semi-colon ";" it can be changed by any character changing IFS=';' 
# in the while loop below.
# # Each line contains 6 columns, columns are parameter values for 
# --host1 --user1 --password1 --host2 --user2 --password2
# and a trailing empty fake column to avoid CR LF part going 
# in the 6th parameter password2. Don't forget the last semicolon.
#
# You can add extra options after the variable "$@" 
# Use character backslash \ at the end of each supplementary line, except for the last one.
# You can also pass extra options via the parameters of this script since
# they will be in "$@"

# The credentials filename "file.txt" used for the loop can be renamed 
# by changing "file.txt" below.


echo Looping on account credentials found in file.txt
echo
line_counter=0
> file_failures.txt
{ while IFS=';' read  h1 u1 p1 h2 u2 p2 fake
    do 
        line_counter=`expr 1 + $line_counter` 
        { echo "$h1" | tr -d '\r' | egrep '^#|^ *$' ; } > /dev/null && continue # this skip commented lines in file.txt
        echo "==== Starting imapsync from host1 $h1 user1 $u1 to host2 $h2 user2 $u2 ===="
        if imapsync --host1 "$h1" --user1 "$u1" --password1 "$p1" \
                 --host2 "$h2" --user2 "$u2" --password2 "$p2" \
                 "$@"
        then
                echo "success sync for line $line_counter "
        else
                echo "$h1;$u1;$p1;$h2;$u2;$p2;" | tee -a file_failures.txt
        fi 
        echo "==== Ended imapsync from host1 $h1 user1 $u1 to host2 $h2 user2 $u2 ===="
        echo
    done 
} < file.txt

