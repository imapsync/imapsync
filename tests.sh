#!/bin/sh

# $Id: tests.sh,v 1.92 2009/07/03 01:00:42 gilles Exp gilles $  

# Example:
# CMD_PERL='perl -I./Mail-IMAPClient-3.14/lib' sh -x tests.sh


HOST1=${HOST1:-'localhost'}
echo HOST1=$HOST1
HOST2=${HOST2:-'localhost'}
echo HOST2=$HOST2

CMD_PERL=${CMD_PERL:-'perl -I./Mail-IMAPClient-2.2.9'}

#### Shell pragmas

exec 3>&2 # 
#set -x   # debug mode. See what is running
set -e    # exit on first failure

#### functions definitions

echo3() {
        #echo '#####################################################' >&3
        echo "$@" >&3
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
        $CMD_PERL -c ./imapsync
}


no_args() {
        $CMD_PERL ./imapsync
}

# list of accounts on plume :

# mailbox toto used on first_sync()
#                      bad_login()
#                      bad_host()

# mailbox titi used on first_sync()
#                      bad_host()
#                      locallocal()

# mailbox tata  used on locallocal()

# mailbox tata titi on most ll_*() tests

# tutu@est.belle # not used

# mailbox tete@est.belle # used on big size tests
#                          big_transfert()
#                          big_transfert_sizes_only()
#                          dprof()

sendtestmessage() {
    email=${1:-"tata"}
    rand=`pwgen 16 1`
    mess='test:'$rand
    cmd="echo $mess""| mail -s ""$mess"" $email"
    echo $cmd
    eval "$cmd"
}


can_send() {
    test X`hostname` = X"plume" && return 0;
    test X`hostname` = X"vadrouille" && return 0;
    return 1
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

option_bad_delete2() {
	! $CMD_PERL ./imapsync --delete 2 --blabla
}

passwords_masked() {
	$CMD_PERL ./imapsync --host1 boumboum --password1 secret --justbanner | grep MASKED
}

first_sync_dry() {
        $CMD_PERL ./imapsync \
            --host1 $HOST1 --user1 toto \
            --passfile1 ../../var/pass/secret.toto \
            --host2 $HOST2 --user2 titi \
            --passfile2 ../../var/pass/secret.titi \
            --noauthmd5 --dry
}



first_sync() {
        $CMD_PERL ./imapsync \
            --host1 $HOST1 --user1 toto \
            --passfile1 ../../var/pass/secret.toto \
            --host2 $HOST2 --user2 titi \
            --passfile2 ../../var/pass/secret.titi \
            --noauthmd5 \
            --allow3xx 
}


locallocal() {
        if can_send; then
                #echo3 Here is plume
                sendtestmessage
        else
                :
        fi
	
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --allow3xx
}

ll_timeout() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --timeout 1 \
            --allow3xx
}

ll_timeout_ssl() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --timeout 5 --ssl1 --ssl2 \
            --allow3xx
}




ll_folder() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop --folder INBOX.Trash \
            --allow3xx
}

ll_oneemail() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.oneemail \
            --allow3xx
}



ll_folderrec() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folderrec INBOX.yop  \
            --allow3xx
}



ll_buffersize() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --buffersize 8 \
            --allow3xx
}


ll_justfolders() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  \
                --allow3xx
                echo "rm -rf /home/vmail/titi/.new_folder/"
}


ll_prefix12() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.qqq  \
                --prefix1 INBOX.\
                --prefix2 INBOX.  \
            --allow3xx
}



ll_internaldate() {
        if can_send; then
                #echo3 Here is plume
                sendtestmessage
        else
                :
        fi
        $CMD_PERL ./imapsync \
         --host1 $HOST1  --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX  \
         --syncinternaldates \
         --allow3xx
}


ll_idatefromheader() {
        if can_send; then
                #echo3 Here is plume
                sendtestmessage
        else
                :
        fi
        $CMD_PERL ./imapsync \
         --host1 $HOST1  --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX.oneemail  \
         --idatefromheader  --debug --dry \
         --allow3xx
}



ll_folder_rev() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 titi \
                --passfile1 ../../var/pass/secret.titi \
                --host2 $HOST2 --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --folder INBOX.yop \
		--allow3xx
}

ll_subscribed()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --subscribed \
            --allow3xx
}


ll_subscribe() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --subscribed --subscribe \
            --allow3xx
}

ll_justconnect() 
{
                $CMD_PERL ./imapsync    \
                --host2 $HOST2 \
                --host1 $HOST1 \
                --justconnect \
            --allow3xx
}

ll_justfoldersizes() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes \
            --allow3xx
}



ll_authmd5() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --authmd5 \
            --allow3xx
}

ll_noauthmd5() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --noauthmd5 \
            --allow3xx
}


ll_maxage() 
{
        if can_send; then
                #echo3 Here is plume
		sendtestmessage
        else
                :
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --maxage 1 \
            --allow3xx
}



ll_maxsize() 
{
        
        if can_send; then
                #echo3 Here is plume
		sendtestmessage
        else
                :
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --maxsize 10 \
            --allow3xx
}

ll_skipsize() 
{
        
        if can_send; then
                #echo3 Here is plume
		sendtestmessage
        else
                :
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --skipsize --folder INBOX.yop.yap \
            --allow3xx
}

ll_skipheader() 
{
        if can_send; then
                #echo3 Here is plume
        	sendtestmessage
        else
                :
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --skipheader 'X-.*' --folder INBOX.yop.yap \
            --allow3xx
}



ll_include() 
{
        if can_send; then
                #echo3 Here is plume
	        sendtestmessage
        else
                :
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --include '^INBOX.yop' \
            --allow3xx
}

ll_exclude() 
{
        if can_send; then
                #echo3 Here is plume
	        sendtestmessage
        else
                :
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --exclude '^INBOX.yop' \
            --allow3xx
}



ll_regextrans2() 
{
        if can_send; then
                #echo3 Here is plume
	        sendtestmessage
        else
                :
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --regextrans2 's/yop/yopX/' \
            --allow3xx
}

ll_sep2() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --sep2 '\\' --dry \
            --allow3xx
}

ll_bad_login()
{
    ! $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 toto \
        --passfile1 ../../var/pass/secret.toto \
        --host2 $HOST2 --user2 notiti \
        --passfile2 ../../var/pass/secret.titi \
            --allow3xx
   
}

ll_bad_host()
{
    ! $CMD_PERL ./imapsync \
        --host1 badhost --user1 toto \
        --passfile1 ../../var/pass/secret.toto \
        --host2 badhost --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
            --allow3xx
   
}

ll_bad_host_ssl()
{
    ! $CMD_PERL ./imapsync \
        --host1 badhost --user1 toto \
        --passfile1 ../../var/pass/secret.toto \
        --host2 badhost --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --ssl1 --ssl2 \
            --allow3xx
}


ll_justfoldersizes()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes \
		--allow3xx
}



ll_useheader() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --useheader 'Message-ID' \
                --dry --debug    \
            --allow3xx
                echo 'rm /home/vmail/tata/.yop.yap/cur/*'
}


ll_regexmess() 
{
        if can_send; then
                rm -f /home/vmail/titi/.yop.yap/cur/*
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --regexmess 's/\157/O/g' \
                --regexmess 's/p/Z/g' \
                 --debug \
            --allow3xx
                
        if can_send; then 	
		file=`ls -t /home/vmail/titi/.yop.yap/cur/* | tail -1`
                diff ../../var/imapsync/tests/ll_regexmess/dest_01 $file
                #echo 'rm -f /home/vmail/titi/.yop.yap/cur/*'
	fi
}

ll_regexmess_scwchu() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.scwchu \
                --regexmess 's{\A(.*?(?! ^$))^Date:(.*?)$}{$1Date:$2\nReceived: From; $2}gxms' \
                --skipsize --skipheader 'Received: From;' \
                --debug  \
		--allow3xx 
                echo 'rm /home/vmail/titi/.scwchu/cur/*'
}


ll_flags() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --dry --debug \
                --allow3xx
                echo 'rm /home/vmail/titi/.yop.yap/cur/*'
}

ll_regex_flag() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --dry --debug --regexflag 's/\\Answered/\\AnXweXed/g' \
                --allow3xx
                
                echo 'rm /home/vmail/titi/.yop.yap/cur/*'
}


ssl_justconnect() {

                $CMD_PERL ./imapsync \
		--host1 $HOST1 \
                --host2 $HOST2 \
                --ssl1 --ssl2 \
                --justconnect \
            --allow3xx
}

ll_ssl() {
        if can_send; then
                #echo3 Here is plume
		sendtestmessage
        else
                :
        fi
        $CMD_PERL ./imapsync \
	 --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --ssl1 --ssl2 \
         --allow3xx
}

ll_authmech_PLAIN() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --nofoldersizes \
                --authmech1 PLAIN --authmech2 PLAIN \
                --allow3xx

}

ll_authuser() {

                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --nofoldersizes \
                --authuser2 titi \
            --allow3xx
}




ll_authmech_LOGIN() {

                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --nofoldersizes \
                --authmech1 LOGIN --authmech2 LOGIN  \
            --allow3xx
}

ll_authmech_CRAMMD5() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --nofoldersizes \
                --authmech1 CRAM-MD5 --authmech2 CRAM-MD5  \
            --allow3xx
}

ll_delete2() {
        if can_send; then
                #echo3 Here is plume
		sendtestmessage titi
        else
                :
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX \
                --delete2 --expunge2 \
            --allow3xx
}

ll_bigmail() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.bigmail \
            --allow3xx
                echo 'rm  /home/vmail/titi/.bigmail/cur/*'
}


msw() {
        sendtestmessage toto
        scp imapsync  Admin@192.168.68.77:'C:/msys/1.0/home/Admin/imapsync/imapsync'
        ssh Admin@192.168.68.77 'C:/msys/1.0/home/Admin/imapsync/test.bat'
}




gmail() {

                $CMD_PERL ./imapsync \
                --allow3xx \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 $HOST2 \
                --ssl2 \
                --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --useheader 'Message-Id'  --skipsize \
                --regextrans2 's/\[Gmail\]/Gmail/' \
                --authmech1 LOGIN \
                --allowsizemismatch
		#--dry # --debug --debugimap # --authmech1 LOGIN

}

gmail_gmail() {

                $CMD_PERL ./imapsync \
                --allow3xx \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
                --useheader 'Message-Id'  --skipsize \
                --regextrans2 's¤INBOX¤inbox_copy¤' \
                --folder INBOX \
                --authmech1 LOGIN --authmech2 LOGIN 
		#--dry # --debug --debugimap # --authmech1 LOGIN

}

gmail_gmail2() {
                $CMD_PERL ./imapsync \
                --allow3xx \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --useheader 'Message-Id'  --skipsize \
                --folder INBOX \
                --authmech1 LOGIN --authmech2 LOGIN 
		#--dry # --debug --debugimap # --authmech1 LOGIN

}


allow3xx() {
        if can_send; then
                #echo3 Here is plume
                sendtestmessage
        else
                :
        fi
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
		--allow3xx 
}



archiveopteryx_1() {
	if can_send; then
                #echo3 Here is plume
                sendtestmessage je@lupus.aox.org
        else
                :
        fi
                $CMD_PERL  ./imapsync \
                --host1 lupus.aox.org --user1 je \
                --passfile1 ../../var/pass/secret.aox_je \
                --host2 lupus.aox.org --user2 je \
                --passfile2 ../../var/pass/secret.aox_je \
                --folder INBOX --regextrans2 's/INBOX/copy/' \
		--allow3xx 
}

justlogin() {
# Look in the file ../../var/pass/secret.tptp to see 
# strange \ character behavior
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
		--allow3xx --justlogin --noauthmd5
}

justlogin_backslash_char() {
# Look in the file ../../var/pass/secret.tptp to see 
# strange \ character behavior
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 tptp@est.belle \
                --passfile2 ../../var/pass/secret.tptp \
		--allow3xx --justlogin --noauthmd5
}


##########################
# specific tests
##########################

big_transfert()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --noauthmd5 \
        --fast --folder INBOX.Trash \
        --useheader Message-ID --useheader Received || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}

big_transfert_sizes_only()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --noauthmd5 \
        --justfoldersizes  --folder INBOX.Trash || \
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
        --passfile1 ../../var/pass/secret \
        --host2 plume --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
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
        --passfile1 ../../var/pass/secret.prw \
        --host2 mail.softwareuno.com \
        --user2 gilles@softwareuno.com \
        --passfile2 ../../var/pass/secret.prw \
        --dry --noauthmd5 --sep1 / --foldersizes --justconnect
}

essnet_mail2_mail()
{
./imapsync \
        --host1 mail2.softwareuno.com \
        --user1 gilles@mail2.softwareuno.com  \
        --passfile1 ../../var/pass/secret.prw \
        --host2 mail.softwareuno.com \
        --user2 gilles@softwareuno.com \
        --passfile2 ../../var/pass/secret.prw \
        --noauthmd5 --sep1 / --foldersizes \
        --prefix2 "INBOX/" --regextrans2 's¤INBOX/INBOX¤INBOX¤'
}

essnet_mail2_mail_t123()
{

for user1 in test1 test2 test3; do
        ./imapsync \
        --host1 mail2.softwareuno.com \
        --user1 ${user1}@mail2.softwareuno.com  \
        --passfile1 ../../var/pass/secret.prw \
        --host2 mail.softwareuno.com \
        --user2 gilles@softwareuno.com \
        --passfile2 ../../var/pass/secret.prw \
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
        --passfile1 ../../var/pass/secret.prw \
        --host2 plume --user2 tata \
        --passfile2 ../../var/pass/secret.tata \
        --noauthmd5 --sep1 / --foldersizes \
        --prefix2 INBOX. --regextrans2 's¤INBOX.INBOX¤INBOX¤'
}

dynamicquest_1()
{

perl -I bugs/lib ./imapsync \
        --host1 69.38.48.81 \
        --user1 testuser1@dq.com \
        --passfile1 ../../var/pass/secret.dynamicquest \
        --host2 69.38.48.81 \
        --user2 testuser2@dq.com \
        --passfile2 ../../var/pass/secret.dynamicquest \
        --noauthmd5 --sep1 "/" --sep2 "/" \
        --justconnect --dry 
}

dynamicquest_2()
{

perl -I bugs/lib ./imapsync \
        --host1 mail.dynamicquest.com \
        --user1 gomez \
        --passfile1 ../../var/pass/secret.dynamicquestgomez \
        --host2 69.38.48.81 \
        --user2 testuser2@dq.com \
        --passfile2 ../../var/pass/secret.dynamicquest \
        --noauthmd5 \
        --justconnect --dry 
}

dynamicquest_3()
{

perl -I bugs/lib ./imapsync \
        --host1 loul \
        --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 69.38.48.81 \
        --user2 testuser2@dq.com \
        --passfile2 ../../var/pass/secret.dynamicquest \
        --noauthmd5 --sep2 "/" --debug --debugimap
        
}

mailenable() {
        ./imapsync \
            --user1 imapsync@damashekconsulting.com \
            --host1  imap.damashekconsulting.com  \
            --passfile1 ../../var/pass/secret.damashek \
            --sep1 "." --prefix1 "" \
            --host2 $HOST2 --user2 toto \
            --passfile2 ../../var/pass/secret.toto \
            --noauthmd5
}

ariasolutions() {
        ./imapsync \
        --host1 209.17.174.20 \
        --user1 chrisw@canadapack.com \
        --passfile1 ../../var/pass/secret.ariasolutions \
        --host2 209.17.174.20 \
        --user2 chrisw@canadapack.com \
        --passfile2 ../../var/pass/secret.ariasolutions \
        --dry --noauthmd5 --justfoldersizes

        ./imapsync \
        --host1 209.17.174.20 \
        --user1 test@domain.local \
        --passfile1 ../../var/pass/secret.ariasolutions \
        --host2 209.17.174.20 \
        --user2 test@domain.local \
        --passfile2 ../../var/pass/secret.ariasolutions \
        --dry --noauthmd5 --ssl1

# hang after auth failure 
        ./imapsync \
        --host1 209.17.174.20 \
        --user1 test@domain.local \
        --passfile1 ../../var/pass/secret.ariasolutions \
        --host2 209.17.174.20 \
        --user2 test@domain.local \
        --passfile2 ../../var/pass/secret.ariasolutions \
        --dry --debug --debugimap

}


ariasolutions2() {
        ./imapsync \
        --host1 209.17.174.12 \
        --user1 chrisw@basebuilding.net \
        --passfile1 ../../var/pass/secret.ariasolutions2 \
        --host2 209.17.174.20 \
        --user2 chrisw@basebuilding.net\
        --passfile2 ../../var/pass/secret.ariasolutions2 \
        --noauthmd5 --syncinternaldates
        # --dry --debug --debugimap


}

genomics() {

# Blocked, timeout ignored
./imapsync \
 --host1 mail.genomics.org.cn --user1 lamiral --passfile1 ../../var/pass/secret.genomics \
 --host2 szmail.genomics.cn   --user2 lamiral --passfile2 ../../var/pass/secret.genomics \
 --sep1 . --prefix1 'INBOX.' --folder INBOX  --useheader 'Message-Id' --expunge --skipsize \
 --timeout 7  --debug --debugimap

}
##########################
##########################





# mandatory tests

run_tests perl_syntax

# All tests

test $# -eq 0 && run_tests \
        no_args \
        option_version \
        option_tests \
	option_bad_delete2 \
        first_sync \
        locallocal \
        ll_timeout \
        ll_folder \
        ll_buffersize \
        ll_justfolders \
        ll_prefix12 \
        ll_internaldate \
        ll_idatefromheader \
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
        ll_exclude \
        ll_regextrans2 \
        ll_sep2 \
        ll_bad_login \
        ll_bad_host \
        ll_bad_host_ssl \
        ll_justfoldersizes \
        ll_useheader \
        ll_regexmess \
        ll_regexmess_scwchu \
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
        gmail \
	gmail_gmail \
	gmail_gmail2 \
	archiveopteryx_1 \
        ssl_justconnect \
	allow3xx \
        justlogin \
	
#       msw
#	justlogin_backslash_char


# selective tests

test $# -gt 0 && run_tests "$@"

# If there, all is good

echo3 ALL $test_count TESTS SUCCESSFUL

