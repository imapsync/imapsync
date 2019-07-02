#!/bin/sh
#
# $Id: sync_parallel_unix.sh,v 1.7 2018/12/06 10:09:03 gilles Exp gilles $

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
# You can add extra options after the last line 
# Use character backslash \ at the end of each supplementary line, except for the last one.


# The credentials filename "file.txt" used for the loop can be renamed 
# by changing "file.txt" below.

# The part 'echo {1} | egrep "^#" > /dev/null ||' is just there to skip commented lines in file.txt
# It can be removed if there is no comment lines in file.txt

# --max-procs 7 means parallel will parallelize up to 7 jobs at a time,
# adjust this value by monitoring your system capacity.

# --delay 2 means parallel will pause 2 seconds after starting each job.

check_parallel_is_here() {
        parallel --version > /dev/null || { echo "parallel command is not installed. Install it first."; return 1; }
}

check_parallel_is_here || exit 1 ;

echo Looping with parallel on account credentials found in file.txt
echo

DRYRUN=echo
# Comment the next line if you want to see the imapsync command instead of running it
DRYRUN=

parallel --max-procs 7 --delay 2 --colsep ';' --arg-file file.txt --line-buffer --tagstring "from {2} to {5} : " \
        'echo {1} | egrep "^#|^ *$" > /dev/null ||' \
        $DRYRUN imapsync --host1 {1} --user1 {2} --password1 {3} \
        --host2 {4} --user2 {5} --password2 {6} 



# {=7=} "$@" 