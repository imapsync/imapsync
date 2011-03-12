#!/bin/sh

# $Id: tests.sh,v 1.68 2007/12/29 02:40:06 gilles Exp gilles $	

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
	for t in "$@"; do
		test_count=`expr 1 + $test_count`
		run_test "$t"
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

# list of accounts on plume :

# toto@est.belle # used on first_sync()
#                          bad_login()
#                          bad_host()

# titi@est.belle # used on first_sync()
#                          bad_host()
#                          locallocal()

# tata@est.belle #  used on locallocal()

# tata titi on most ll_*() tests

# tutu@est.belle # not used

# tete@est.belle # used on big size tests
#                          big_transfert()
#                          big_transfert_sizes_only()
#                          dprof()

sendtestmessage() {
    email=${1:-"tata@est.belle"}
    rand=`pwgen 16 1`
    mess='test:'$rand
    cmd="echo $mess""| mail -s ""$mess"" $email"
    echo $cmd
    eval "$cmd"
}


zzzz() {
	$CMD_PERL -V

}

option_version() {
	$CMD_PERL ./imapsync --version
}


option_tests() {
	$CMD_PERL ./imapsync --tests
}


first_sync_dry() {
	$CMD_PERL ./imapsync \
	    --host1 localhost --user1 toto@est.belle \
	    --passfile1 /var/tmp/secret1 \
	    --host2 localhost --user2 titi@est.belle \
	    --passfile2 /var/tmp/secret.titi \
	    --noauthmd5 --dry
}



first_sync() {
	$CMD_PERL ./imapsync \
	    --host1 localhost --user1 toto@est.belle \
	    --passfile1 /var/tmp/secret1 \
	    --host2 localhost --user2 titi@est.belle \
	    --passfile2 /var/tmp/secret.titi \
	    --noauthmd5
}


locallocal() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		sendtestmessage
		$CMD_PERL  ./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
	else
		:
	fi
}



ll_folder() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		$CMD_PERL ./imapsync \
		--host1 localhost  --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folder INBOX.yop --folder INBOX.Trash
	else
		:
	fi
}

ll_folderrec() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		$CMD_PERL ./imapsync \
		--host1 localhost  --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folderrec INBOX.yop 
	else
		:
	fi
}



ll_buffersize() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		$CMD_PERL ./imapsync \
		--host1 localhost  --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--buffersize 8
	else
		:
	fi
}



ll_justfolders() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		$CMD_PERL ./imapsync \
		--host1 localhost  --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--justfolders 
	else
		:
	fi
}


ll_prefix12() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		$CMD_PERL ./imapsync \
		--host1 localhost  --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folder INBOX.qqq  \
		--prefix1 INBOX.\
		--prefix2 INBOX. 
	else
		:
	fi
}



ll_internaldate() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		sendtestmessage
		./imapsync \
		--host1 localhost  --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folder INBOX  \
		--syncinternaldates
	else
		:
	fi
}




ll_folder_rev() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost  --user1 titi@est.belle \
		--passfile1 /var/tmp/secret.titi \
		--host2 localhost --user2 tata@est.belle \
		--passfile2 /var/tmp/secret.tata \
		--folder INBOX.yop
	else
		:
	fi
}

ll_subscribed()
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost  --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--subscribed
	else
		:
	fi
}


ll_subscribe() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost  --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--subscribed --subscribe
	else
		:
	fi
}

ll_justconnect() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync    \
		--host2 localhost \
		--host1 localhost \
		--justconnect
	else
		:
	fi
}

ll_justfoldersizes() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--justfoldersizes
	else
		:
	fi
}



ll_authmd5() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--justfoldersizes --authmd5
	else
		:
	fi
}

ll_noauthmd5() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--justfoldersizes --noauthmd5
	else
		:
	fi
}


ll_maxage() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--maxage 1
	else
		:
	fi
}



ll_maxsize() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--maxsize 10
	else
		:
	fi
}

ll_skipsize() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--skipsize --folder INBOX.yop.yap
	else
		:
	fi
}

ll_skipheader() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--skipheader 'X-.*' --folder INBOX.yop.yap
	else
		:
	fi
}



ll_include() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--include '^INBOX.yop'
	else
		:
	fi
}

ll_regextrans2() 
{
	sendtestmessage
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--regextrans2 's/yop/yopX/'
	else
		:
	fi
}

ll_sep2() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folder INBOX.yop.yap \
		--sep2 '\\' --dry
	else
		:
	fi
}

ll_bad_login()
{
    ! ./imapsync \
	--host1 localhost --user1 toto@est.belle \
	--passfile1 /var/tmp/secret1 \
	--host2 localhost --user2 notiti@est.belle \
	--passfile2 /var/tmp/secret2
   
}

ll_bad_host()
{
    ! ./imapsync \
	--host1 badhost --user1 toto@est.belle \
	--passfile1 /var/tmp/secret1 \
	--host2 badhost --user2 titi@est.belle \
	--passfile2 /var/tmp/secret2
   
}

ll_bad_host_ssl()
{
    ! ./imapsync \
	--host1 badhost --user1 toto@est.belle \
	--passfile1 /var/tmp/secret1 \
	--host2 badhost --user2 titi@est.belle \
	--passfile2 /var/tmp/secret2 \
        --ssl1 --ssl2
}


ll_justfoldersizes()
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--justfoldersizes
	else
		:
	fi
}



ll_useheader() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folder INBOX.yop.yap \
		--useheader 'Message-ID' \
		--dry --debug	
		echo 'rm /home/vmail/tata/.yop.yap/cur/*'
	else
		:
	fi
}


ll_regexmess() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folder INBOX.yop.yap \
		--regexmess 's/\157/O/g' \
		--regexmess 's/p/Z/g' \
		--dry --debug
		echo 'rm /home/vmail/titi/.yop.yap/cur/*'
	else
		:
	fi
}


ll_flags() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folder INBOX.yop.yap \
		--dry --debug
		echo 'rm /home/vmail/titi/.yop.yap/cur/*'
	else
		:
	fi
}

ll_regex_flag() 
{
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folder INBOX.yop.yap \
		--dry --debug --regexflag 's/\\Answered/\\AnXweXed/g'
		
		echo 'rm /home/vmail/titi/.yop.yap/cur/*'
	else
		:
	fi
}


ll_ssl() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--ssl1 --ssl2
	else
		:
	fi
}

ll_authmech_PLAIN() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--justfoldersizes --nofoldersizes \
		--authmech1 PLAIN --authmech2 PLAIN
	else
		:
	fi
}

ll_authuser() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--justfoldersizes --nofoldersizes \
		--authuser2 titi@est.belle
	else
		:
	fi
}




ll_authmech_LOGIN() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--justfoldersizes --nofoldersizes \
		--authmech1 LOGIN --authmech2 LOGIN 
	else
		:
	fi
}

ll_authmech_CRAMMD5() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--justfoldersizes --nofoldersizes \
		--authmech1 CRAM-MD5 --authmech2 CRAM-MD5 
	else
		:
	fi
}

ll_delete2() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
                --folder INBOX \
		--delete2 --expunge2
	else
		:
	fi
}

ll_bigmail() {
	if test X`hostname` = X"plume"; then
		echo3 Here is plume
		./imapsync \
		--host1 localhost  --user1 tata@est.belle \
		--passfile1 /var/tmp/secret.tata \
		--host2 localhost --user2 titi@est.belle \
		--passfile2 /var/tmp/secret.titi \
		--folder INBOX.bigmail
		echo 'rm  /home/vmail/titi/.bigmail/cur/*'
	else
		:
	fi
}


msw() {
	sendtestmessage toto@est.belle
	scp imapsync  Admin@192.168.68.77:'C:/msys/1.0/home/Admin/imapsync/imapsync'
	ssh Admin@192.168.68.77 'C:/msys/1.0/home/Admin/imapsync/test.bat'
}


##########################
# specific tests
##########################

big_transfert()
{
    date1=`date`
    { ./imapsync \
	--host1 louloutte --user1 gilles \
	--passfile1 /var/tmp/secret \
	--host2 plume --user2 tete@est.belle \
	--passfile2 /var/tmp/secret.tete \
	--subscribed --foldersizes --noauthmd5 \
        --fast --folder INBOX.Backup \
	--useheader Message-ID --useheader Received || \
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
	--subscribed  --noauthmd5 \
	--justfoldersizes  || \
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
        --debug \
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
        --noauthmd5 --sep1 / --foldersizes \
        --prefix2 INBOX. --regextrans2 's¤INBOX.INBOX¤INBOX¤'
}

dynamicquest_1()
{

perl -I bugs/lib ./imapsync \
	--host1 69.38.48.81 \
	--user1 testuser1@dq.com \
	--passfile1 /var/tmp/secret.dynamicquest \
	--host2 69.38.48.81 \
	--user2 testuser2@dq.com \
	--passfile2 /var/tmp/secret.dynamicquest \
	--noauthmd5 --sep1 "/" --sep2 "/" \
	--justconnect --dry 
}

dynamicquest_2()
{

perl -I bugs/lib ./imapsync \
	--host1 mail.dynamicquest.com \
	--user1 gomez \
	--passfile1 /var/tmp/secret.dynamicquestgomez \
	--host2 69.38.48.81 \
	--user2 testuser2@dq.com \
	--passfile2 /var/tmp/secret.dynamicquest \
	--noauthmd5 \
	--justconnect --dry 
}

dynamicquest_3()
{

perl -I bugs/lib ./imapsync \
	--host1 loul \
	--user1 tata \
	--passfile1 /var/tmp/secret.tata \
	--host2 69.38.48.81 \
	--user2 testuser2@dq.com \
	--passfile2 /var/tmp/secret.dynamicquest \
	--noauthmd5 --sep2 "/" --debug --debugimap
	
}

mailenable() {
	./imapsync \
	    --user1 imapsync@damashekconsulting.com \
	    --host1  imap.damashekconsulting.com  \
	    --passfile1 /var/tmp/secret.damashek \
	    --sep1 "." --prefix1 "" \
	    --host2 localhost --user2 toto@est.belle \
	    --passfile2 /var/tmp/secret1 \
	    --noauthmd5
}

ariasolutions() {
	./imapsync \
	--host1 209.17.174.20 \
	--user1 chrisw@canadapack.com \
	--passfile1 /var/tmp/secret.ariasolutions \
	--host2 209.17.174.20 \
	--user2 chrisw@canadapack.com \
	--passfile2 /var/tmp/secret.ariasolutions \
	--dry --noauthmd5 --justfoldersizes

	./imapsync \
	--host1 209.17.174.20 \
	--user1 test@domain.local \
	--passfile1 /var/tmp/secret.ariasolutions \
	--host2 209.17.174.20 \
	--user2 test@domain.local \
	--passfile2 /var/tmp/secret.ariasolutions \
	--dry --noauthmd5 --ssl1

# hang after auth failure 
	./imapsync \
	--host1 209.17.174.20 \
	--user1 test@domain.local \
	--passfile1 /var/tmp/secret.ariasolutions \
	--host2 209.17.174.20 \
	--user2 test@domain.local \
	--passfile2 /var/tmp/secret.ariasolutions \
	--dry --debug --debugimap

}


ariasolutions2() {
	./imapsync \
	--host1 209.17.174.12 \
	--user1 chrisw@basebuilding.net \
	--passfile1 /var/tmp/secret.ariasolutions2 \
	--host2 209.17.174.20 \
	--user2 chrisw@basebuilding.net\
	--passfile2 /var/tmp/secret.ariasolutions2 \
	--noauthmd5 --syncinternaldates
	# --dry --debug --debugimap


}
##########################
##########################





# mandatory tests

run_tests perl_syntax 

# All tests
# lp : louloutte -> plume
# pl : plume -> louloutte

test $# -eq 0 && run_tests \
	no_args \
        option_version \
	option_tests \
	first_sync \
	locallocal \
	ll_folder \
 	ll_buffersize \
	ll_justfolders \
 	ll_prefix12 \
 	ll_internaldate \
 	ll_folder_rev \
 	ll_subscribed \
 	ll_subscribe \
 	ll_justconnect \
	ll_justfoldersizes \
	ll_authmd5 \
	ll_noauthmd5 \
	ll_maxage \
 	ll_maxsize \
	ll_skipsize \
	ll_skipheader \
	ll_include \
	ll_regextrans2 \
	ll_sep2 \
	ll_bad_login \
	ll_bad_host \
	ll_bad_host_ssl \
	ll_justfoldersizes \
	ll_useheader \
	ll_regexmess \
	ll_flags \
	ll_regex_flag \
	ll_ssl \
	ll_authmech_PLAIN \
	ll_authmech_LOGIN \
	ll_authmech_CRAMMD5 \
	ll_authuser \
	ll_delete2 \
	ll_folderrec \
	ll_bigmail \
	msw



# selective tests

test $# -gt 0 && run_tests "$@"

# If there, all is good

echo3 ALL $test_count TESTS SUCCESSFUL

