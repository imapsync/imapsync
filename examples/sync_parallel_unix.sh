#!/bin/sh
#
# $Id: sync_parallel_unix.sh,v 1.2 2018/02/12 21:53:16 gilles Exp gilles $

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

# The part 'echo {1} | egrep "^#" > /dev/null ||' is just there to skip commented lines in file.txt
# It can be removed if there is no comment lines in file.txt

echo Looping with parallel on account credentials found in file.txt
echo

DRYRUN=echo
#DRYRUN=

parallel --colsep ';' -a file.txt 'echo {1} | egrep "^#|^ *$" > /dev/null ||' \
        $DRYRUN imapsync --host1 {1} --user1 {2} --password1 {3} \
        --host2 {4} --user2 {5} --password2 {6} {=7=} "$@" 

