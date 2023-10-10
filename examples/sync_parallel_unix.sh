#!/bin/sh
#
# $Id: sync_parallel_unix.sh,v 1.11 2022/01/13 12:56:28 gilles Exp gilles $

# If you're on Windows there is a possibility to install and use parallel
# but I have never tested it. I found:
# https://stackoverflow.com/questions/52393850/how-to-install-gnu-parallel-on-windows-10-using-git-bash


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
# --max-procs 3 means parallel will parallelize up to 3 jobs at a time,
# adjust this value by monitoring your system capacity.
#
# --delay 1.4 means parallel will pause 1.4 seconds (1400 ms) after starting each job.
#
#  --colsep ';' means the separator between values is the character semi-colon ;
# 
# --arg-file file.txt means the actual input file is named file.txt
# 
# --line-buffer means outputs will be of whole lines instead of a big mess
#  of part of them for the different processes. One line belongs to one process.
# 
# --tagstring "from {2} to {5} : " mean that each line will begin with the 
# words "from {2} to {5} : " where {2} will be replaced by the second column
# and {5}  will be replaced by the fifth column. Hack this part as you wish


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

# {1} will be replaced by the first column in file.txt 
# {2} will be replaced by the second column in file.txt 
# {3} will be replaced by the third column in file.txt 
# ...


# "$@" will be replaced by the parameters of this script itself,
# the one you are reading now. It's useful if you want to
# add temporarily a parameter for all runs without editing any file.
# For example, 
#   sync_parallel_unix.sh --justlogin 
# will run all imapsync with the --justlogin parameter added.

# --simulong 5 is just there to show that you can also add parameters
# here and that you have read this section. --simulong 5 does nothing
# else than printing "Are you still here ETA: xx/25 msgs left"
# five times per second. It will show the living output of all
# paralelized runs


# The current script does not take into account what is in the 7th column

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

parallel --max-procs 3 --delay 1.4 --colsep ';' --arg-file file.txt --line-buffer --tagstring "from {2} to {5} : " \
        'echo {1} | egrep "^#|^ *$" > /dev/null ||' \
        $DRYRUN imapsync --host1 {1} --user1 {2} --password1 {3} \
        --host2 {4} --user2 {5} --password2 {6}  "$@" --simulong 5 



# A question to ask to the parallel mailing-list, Ole Tange
# does not work like I want, it passes all the 7th column as only one argument to imapsync:
# '{=7 split / /, $arg[7] =}' 
# I want a list of arguments
