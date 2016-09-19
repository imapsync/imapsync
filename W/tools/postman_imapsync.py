#!/usr/bin/python

# Postman_imapsync.py 
#
# Author: Jacek Falatowicz 2016

# This script allowes you to run multiple threads of imapsync ( http://imapsync.lamiral.info/ )
# It needs postman_batch.csv (in same directory) file that contains a list of users and passwords.
# It assumes that username on both servers are same. 
# First two lines of that file are reserved for mail servers.

# Example line of first lines of postman_batch.csv:
# serv1: mail.server1.com
# serv2: mail.server2.com
# john.doe@example.domain,Password1,Password2
# jane.doe@example.domain,Password1,Password2

# It has to be run from the same directory where your imapsync is.
# 

import subprocess
from multiprocessing.dummy import Pool as ThreadPool

# preparation() reads from the postman_batch.csv 
def preparation():
	command="grep -e \"^serv1:\" -e \"^serv2:\" postman_batch.csv| awk '{print $2}'"
	serv = subprocess.Popen(['/bin/bash', '-c',  command], stdout=subprocess.PIPE).communicate()
	serv = serv[0].strip().split("\n")
	print serv
	command="grep -v -e \"^serv1:\" -e \"^serv2:\" postman_batch.csv| awk -F\",\" '{print $1\" \"$2\" \"$1\" \"$3\" \"$1\" %s %s\"}'|awk '{gsub(\"@.+\",\"\",$5); print}'" % (serv[0],serv[1])
	print command
	reading = subprocess.Popen(['/bin/bash', '-c',  command], stdout=subprocess.PIPE).communicate()
	reading = reading[0].strip().split("\n")
	users=[]
	for i in range(0,len(reading)):
		users.append(reading[i].split(" "))
	return users

# postman_imapsync() runs imapsync 
def postman_imapsync(user):
	command="./imapsync --host1 "+ user[5] +" \
--user1 "+ user[0] +" \
--password1 "+ user[1] +" \
--ssl1 --host2 "+ user[6] +" \
--user2 "+ user[2] +" \
--password2 "+ user[3] +" \
--ssl2 --nofoldersizes --skipsize --fast \
--pidfile \"./"+ user[4] +".pid\" \
--pidfilelocking --logdir \".\" --logfile \"./log/sync."+ user[4] +".log\" --tmpdir \"./tmp\""
	print command		# this will print command that was executed on your STDOUT
	subprocess.Popen(['/bin/bash', '-c',  command], stdout=subprocess.PIPE).communicate()


# Magic:

users = preparation()
for i in range(0,len(users)):
	print users[i]

# Here you can specify how many threads of imapsync you want to run (default 4)
pool=ThreadPool(4)
results = pool.map(postman_imapsync, users)
pool.close()
pool.join()


