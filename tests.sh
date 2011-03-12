#!/bin/sh

# $Id: tests.sh,v 1.4 2003/08/21 15:40:32 gilles Exp $	

# $Log: tests.sh,v $
# Revision 1.4  2003/08/21 15:40:32  gilles
# Added a email in loulplume test
#
# Revision 1.3  2003/05/05 22:32:01  gilles
# Added pl_folder() test
#
# Revision 1.2  2003/05/05 21:05:49  gilles
# Added lp_folder to test --folder option
#
# Revision 1.1  2003/03/12 23:14:45  gilles
# Initial revision
#


#### Shell pragmas

exec 3>&2 # 
#set -x   # debug mode. See what is running
set -e    # exit on first failure

#### functions definitions

echo3() {
	#echo '#####################################################' >&3
	echo "$*" >&3
}

run_test() {
	echo3 "#### $test_count $1"
	$1
	if test x"$?" = x"0"; then
 		echo "$1 passed"
	else
		echo "$1 failed" >&2
	fi
}

run_tests() {
	for t in $*; do
		test_count=`expr 1 + $test_count`
		run_test $t
		sleep 1
	done
}


#### Variable definitions

prog=imapsync
host1=localhost
host2=localhost
passfile1=/var/tmp/secret1
passfile2=/var/tmp/secret2
user1=toto@est.belle
user2=titi@est.belle

dirtest=/tmp/${prog}/test

test_count=0

##### The tests functions

perl_syntax() {
	perl -c ./${prog}
}


no_args() {
	./${prog}
}

cleaning_test_directory() {
	test -d $dirtest && find  $dirtest -type d| xargs chmod 700
	rm -rf $dirtest
	mkdir -p $dirtest
}


first_sync() {
	./imapsync \
	   --host1 $host1 --user1 $user1 --passfile1 $passfile1 \
	   --host2 $host2 --user2 $user2 --passfile2 $passfile2
}

loulplume() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		rand=`pwgen 16 1`
		mess='test:'$rand
		cmd="echo $mess""| mail -s ""$mess"" tata"
		echo $cmd
		ssh gilles@loul $cmd
		sleep 10
		./imapsync \
		--host1 loul  --user1 tata --passfile1 /var/tmp/secret.tata \
		--host2 plume --user2 tata@est.belle --passfile2 /var/tmp/secret.tata
	else
		:
	fi
}

plumeloul() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 plume --user1 tata@est.belle --passfile1 /var/tmp/secret.tata \
		--host2 loul  --user2 tata --passfile2 /var/tmp/secret.tata
	else
		:
	fi
}

lp_folder() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle --passfile2 /var/tmp/secret.tata \
		--folder INBOX.yop --folder INBOX.Trash  \
		--host1 loul  --user1 tata --passfile1 /var/tmp/secret.tata
	else
		:
	fi
}

pl_folder() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 plume --user1 tata@est.belle --passfile1 /var/tmp/secret.tata \
		--folder INBOX.yop \
		--host2 loul  --user2 tata --passfile2 /var/tmp/secret.tata
	else
		:
	fi
}


# mandatory tests

run_tests perl_syntax 

# All tests

test $# -eq 0 && run_tests \
	no_args \
	first_sync \
	loulplume \
	plumeloul \
	lp_folder \
	pl_folder

# selective tests

test $# -gt 0 && run_tests $*

# If there, all is good

echo3 ALL $test_count TESTS SUCCESSFUL

