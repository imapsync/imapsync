#!/bin/sh

# $Id: tests.sh,v 1.35 2005/01/17 14:47:49 gilles Exp $	

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
	    --passfile2 /var/tmp/secret2 \
	    --noauthmd5
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
		--passfile2 /var/tmp/secret.tata \
		--nosyncacls
	else
		:
	fi
}

loulloul() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		sendtestmessage
		#sleep 10
		./imapsync \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--host2 loul --user2 titi \
		--passfile2 /var/tmp/secret.tata \
		--sep2 .
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

lp_justfolders() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--folder INBOX.yop --folder INBOX.Trash  \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--justfolders
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

lp_skipsize() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--skipsize --folder INBOX.yop.yap
	else
		:
	fi
}

lp_skipheader() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--skipheader 'X-.*' --folder INBOX.yop.yap
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

lp_regextrans2() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--regextrans2 's/yop/yopX/' --dry
	else
		:
	fi
}

lp_sep2() 
{
	
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--folder INBOX.yop.yap \
		--sep2 '\\' --dry
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


foldersizes()
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--justconnect --foldersizes
	else
		:
	fi

}


foldersizes2()
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		perl -I ~gilles/build/Mail-IMAPClient-2.2.8/blib/lib/ \
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--justconnect --foldersizes
	else
		:
	fi

}


big_transfert()
{
    date1=`date`
    { ./imapsync \
	--host1 louloutte --user1 gilles \
	--passfile1 /var/tmp/secret \
	--host2 plume --user2 tete@est.belle \
	--passfile2 /var/tmp/secret.tete \
	--subscribed --foldersizes --noauthmd5 \
        --fast --folder INBOX.Backup || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}

big_transfert_sizes_only()
{
    date1=`date`
    { ./imapsync \
	--host1 louloutte --user1 gilles \
	--passfile1 /var/tmp/secret \
	--host2 plume --user2 tete@est.belle \
	--passfile2 /var/tmp/secret.tete \
	--subscribed --foldersizes --noauthmd5 \
	--justconnect --fast || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}



dprof()
{
    date1=`date`
    { perl -d:DProf ./imapsync \
	--host1 louloutte --user1 gilles \
	--passfile1 /var/tmp/secret \
	--host2 plume --user2 tete@est.belle \
	--passfile2 /var/tmp/secret.tete \
	--subscribed --foldersizes --noauthmd5 \
        --folder INBOX.Trash || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
    dprofpp tmon.out
}

essnet_justconnect()
{
./imapsync \
	--host1 mail2.softwareuno.com \
	--user1 gilles@mail2.softwareuno.com  \
	--passfile1 /var/tmp/secret.prw \
	--host2 mail.softwareuno.com \
	--user2 gilles@softwareuno.com \
	--passfile2 /var/tmp/secret.prw \
	--dry --noauthmd5 --sep1 / --foldersizes --justconnect
}

essnet_mail2_mail()
{
./imapsync \
	--host1 mail2.softwareuno.com \
	--user1 gilles@mail2.softwareuno.com  \
	--passfile1 /var/tmp/secret.prw \
	--host2 mail.softwareuno.com \
	--user2 gilles@softwareuno.com \
	--passfile2 /var/tmp/secret.prw \
	--noauthmd5 --sep1 / --foldersizes \
	--nosyncacls \
        --prefix2 "INBOX/" --regextrans2 's¤INBOX/INBOX¤INBOX¤'
}

essnet_mail2_mail_t123()
{

for user1 in test1 test2 test3; do
	./imapsync \
	--host1 mail2.softwareuno.com \
	--user1 ${user1}@mail2.softwareuno.com  \
	--passfile1 /var/tmp/secret.prw \
	--host2 mail.softwareuno.com \
	--user2 gilles@softwareuno.com \
	--passfile2 /var/tmp/secret.prw \
	--noauthmd5 --sep1 / --foldersizes \
	--prefix2 "INBOX/" --regextrans2 's¤INBOX/INBOX¤INBOX¤' \
        --nosyncacls --debug \
	|| true
done
}


essnet_plume2()
{
./imapsync \
	--host1 mail2.softwareuno.com \
	--user1 gilles@mail2.softwareuno.com  \
	--passfile1 /var/tmp/secret.prw \
	--host2 plume --user2 tata@est.belle \
	--passfile2 /var/tmp/secret.tata \
	--nosyncacls \
        --noauthmd5 --sep1 / --foldersizes \
        --prefix2 INBOX. --regextrans2 's¤INBOX.INBOX¤INBOX¤' \
	--nosyncacls 
}

regexmess() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		
		./imapsync \
		--host2 plume --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--host1 loul  --user1 tata \
		--passfile1 /var/tmp/secret.tata \
		--folder INBOX.yop.yap \
		--regexmess 's/\157/O/g' \
		--regexmess 's/p/Z/g' \
		--dry --debug
		
		echo 'rm /home/vmail/tata/.yop.yap/cur/*'
	else
		:
	fi
}


# mandatory tests

run_tests perl_syntax 

# All tests
# lp : louloutte -> plume
# pl : plume -> louloutte

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
	lp_noauthmd5 \
        lp_skipsize \
        lp_skipheader \
	lp_regextrans2 \
	foldersizes2 \
	foldersizes \
	big_transfert_sizes_only \
	regexmess \
	


# selective tests

test $# -gt 0 && run_tests $*

# If there, all is good

echo3 ALL $test_count TESTS SUCCESSFUL

