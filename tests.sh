#!/bin/sh

# $Id: tests.sh,v 1.15 2004/03/11 05:32:08 gilles Exp $	

# $Log: tests.sh,v $
# Revision 1.15  2004/03/11 05:32:08  gilles
# Added bad_login()
# Added bad_host()
# Added lp_noauthmd5()
#
# Revision 1.14  2004/02/07 03:34:35  gilles
# Added lp_include()
#
# Revision 1.13  2004/01/29 04:21:54  gilles
# Added lp_maxage
# Added lp_maxsize
#
# Revision 1.12  2003/12/23 18:16:09  gilles
# Added lp_justconnect()
# Added lp_md5auth()
#
# Revision 1.11  2003/12/12 17:48:02  gilles
# Added lp_subscribe() test
#
# Revision 1.10  2003/11/21 03:20:14  gilles
# Renamed lp_folder_qqq() pl_folder_qqq()
# Removed --prefix2 INBOX. in pl_folder_qqq()
# Added lp_subscribed() test.
#
# Revision 1.9  2003/10/20 22:53:29  gilles
# Added lp_internaldate()
#
# Revision 1.8  2003/10/20 21:49:47  gilles
# wrote sendtestmessage()
#
# Revision 1.7  2003/10/17 01:34:16  gilles
# Added lp_folder_qqq() test
#
# Revision 1.6  2003/08/24 01:56:49  gilles
# Indented long lines
#
# Revision 1.5  2003/08/24 01:05:35  gilles
# Removed some variables
#
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

test_count=0

##### The tests functions

perl_syntax() {
	perl -c ./imapsync
}


no_args() {
	./imapsync
}


first_sync() {
	./imapsync \
	    --host1 localhost --user1 toto@est.belle \
	    --passfile1 /var/tmp/secret1 \
	    --host2 localhost --user2 titi@est.belle \
	    --passfile2 /var/tmp/secret2
}

sendtestmessage() {
    rand=`pwgen 16 1`
    mess='test:'$rand
    cmd="echo $mess""| mail -s ""$mess"" tata"
    echo $cmd
    ssh gilles@loul $cmd
}

loulplume() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		sendtestmessage
		#sleep 10
		./imapsync \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata
	else
		:
	fi
}

plumeloul() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 plume --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 loul  --user2 tata \
		--passfile2 /var/tmp/secret.tata
	else
		:
	fi
}

lp_folder() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--folder INBOX.yop --folder INBOX.Trash  \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata
	else
		:
	fi
}


pl_folder_qqq() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 plume --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--folder INBOX.qqq  \
		--prefix2 "" \
		--host2 loul  --user2 tata \
		--passfile2 /var/tmp/secret.tata
	else
		:
	fi
}

lp_internaldate() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		sendtestmessage
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--folder INBOX  \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--syncinternaldates
	else
		:
	fi
}




pl_folder() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 plume --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--folder INBOX.yop \
		--host2 loul  --user2 tata \
		--passfile2 /var/tmp/secret.tata
	else
		:
	fi
}

lp_subscribed() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--subscribed
	else
		:
	fi
}


lp_subscribe() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--subscribed --subscribe
	else
		:
	fi
}

lp_justconnect() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--justconnect
	else
		:
	fi
}

lp_authmd5() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		perl -I ~gilles/build/Mail-IMAPClient-2.2.8/blib/lib/ \
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--justconnect
	else
		:
	fi
}

lp_noauthmd5() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		perl -I ~gilles/build/Mail-IMAPClient-2.2.8/blib/lib/ \
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--justconnect --noauthmd5
	else
		:
	fi
}


lp_maxage() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--maxage 1
	else
		:
	fi
}

lp_maxsize() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--maxsize 10
	else
		:
	fi
}

lp_include() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--include 'INBOX.yop'
	else
		:
	fi
}

bad_login()
{
    ! ./imapsync \
	--host1 localhost --user1 toto@est.belle \
	--passfile1 /var/tmp/secret1 \
	--host2 localhost --user2 notiti@est.belle \
	--passfile2 /var/tmp/secret2
   
}

bad_host()
{
    ! ./imapsync \
	--host1 localhost --user1 toto@est.belle \
	--passfile1 /var/tmp/secret1 \
	--host2 badhost --user2 titi@est.belle \
	--passfile2 /var/tmp/secret2
   
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
	pl_folder \
        pl_folder_qqq \
	lp_internaldate \
	lp_subscribed \
	lp_subscribe \
	lp_justconnect \
	lp_authmd5 \
	lp_maxage \
	lp_maxsize \
	lp_include \
	bad_login \
	bad_host \
	lp_noauthmd5

# selective tests

test $# -gt 0 && run_tests $*

# If there, all is good

echo3 ALL $test_count TESTS SUCCESSFUL

