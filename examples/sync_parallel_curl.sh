#!/bin/sh
#
# $Id: sync_parallel_curl.sh,v 1.2 2020/11/16 00:40:06 gilles Exp gilles $

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
#
# Extra columns can be used to pass extra parameters but the script reading
# this file have to read them into some variables.
#
# Last, don't forget the last semicolon.
#
# You can add extra options after the last line 
# Use character backslash \ at the end of each supplementary line, except for the last one.


# The credentials filename "file.txt" used for the loop can be renamed 
# by changing "file.txt" below.

# Now I explain what come next, the actual stuff, which is barely 
# a single long command line written on several lines for the reading 
# convenience

# The first word is the parallel command itself, it's a perl utility 
# written by Ole Tange, available on Linux systems, already packaged. 
# It is also called GNU Parallel. The GNU Parallel homepage is
# https://www.gnu.org/software/parallel/
# Parallel is very powerful, you could easily distribute the parallel stuff
# on remote machines with it (not used here).

# The parallel command is then followed by its parameters.
# parallel parameters explained:
#
# --max-procs jobs means parallel will parallelize up to x jobs at a time,
# x being the number stored in the file jobs.
# Adjust this value by monitoring your system capacity and changing it with 
# echo 7 > jobs
#
# --delay 1.1 means parallel will pause 1.1 seconds after starting each job.
#
#  --colsep ';' means the separator between values is the character semi-colon ;
# 
# --arg-file file.txt means the actual input file is named file.txt
# 
# --line-buffer means outputs will be of whole lines instead of a big mess
#  of part of them for the different processes. One line belongs to one process.
# 
# --tagstring "job {#} slot {%} using {1} from {3} to {6} : "
# means that each line will begin with the 
# words "job {#} slot {%} using {1} from {3} to {6} : " 
# where:
# {1} will be replaced by the column of the file servers.txt, aka the CGI imapsync url
# {3} will be replaced by the second column element, aka user1
# {6} will be replaced by the fifth column element, aka user2. 
# Hack this part as you wish


# The remaining parameters is the command to be executed by the parallel 
# command, ie, the command to be run several times in parallel with 
# different parameters each time. 

# Some explanations about this remaining parts.
#
# The part 'echo {1} | egrep "^#" > /dev/null ||' is just there to skip 
# commented lines in file.txt
# It can be removed if there is no comment lines in file.txt

# The part $DRYRUN is a variable that can be either the echo command
# or nothing. It is a trick to permit you to see the command and its 
# parameters without running it
# 


# {2} will be replaced by the first column in file.txt 
# {3} will be replaced by the second column in file.txt 
# {4} will be replaced by the third column in file.txt 
# ...


# "$@" will be replaced by the parameters of this script itself,
# the one you are reading now. It's useful if you want to
# add temporarily a parameter for all runs without editing any file.
# For example, 
#   sync_parallel_curl.sh --justlogin 
# will run all imapsync with the --justlogin parameter added.



check_parallel_is_here() {
        parallel --version > /dev/null || { echo "parallel command is not installed. Install it first."; return 1; }
}

# First, there is no need to go further if the parallel command is not available
# one the current system.

check_parallel_is_here || exit 1 ;

echo Looping with parallel on account credentials found in file.txt
echo


DRYRUN=echo
# Comment the next line if you want to see the imapsync command instead of running it
# since the previous echo value will be discarded
DRYRUN=

parallel --max-procs jobs --delay 1.1 --colsep ';' --link --arg-file servers.txt --arg-file file.txt --line-buffer --tagstring "job {#} slot {%} using {1} from {3} to {6} : " \
        'echo {1} | egrep "^#|^ *$" > /dev/null ||' \
        $DRYRUN "curl -k -s -d 'host1='{2}';user1='{3}';password1='{4}';host2='{5}';user2='{6}';password2='{7} {1}"

