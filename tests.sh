#!/bin/sh

# $Id: tests.sh,v 1.374 2022/09/15 08:43:20 gilles Exp gilles $  

# To run these tests, you need a running imap server somewhere
# with several accounts. And be on Linux or Unix.
# 
# Tests will break as they are home specific, they depend on the content
# of the mailboxes, which are not given here.
# 
# Anyway, those tests are good as imapsync examples.
# 
# All mandatory tests are run with:
# 
# sh tests.sh
# 
# Specific tests can be run by using them as arguments to tests.sh:
# 
# sh tests.sh ll_ssl_justconnect  ll_bad_host ...



HOST1=${HOST1:-'localhost'}
echo HOST1=$HOST1
HOST2=${HOST2:-'localhost'}
echo HOST2=$HOST2

# most tests use:

CMD_PERL='perl -I./W/Mail-IMAPClient-3.43/lib'


#### Shell pragmas



#### functions definitions

# File handle 3 is redirected to STDERR so that echo3 prints 
# on the terminal even with "sh test.sh > /dev/null"
# I want to see the names of the tests and their count while 
# they're running but I don't want to see their output, it's too noisy.

exec 3>&2 
echo3() {
        #echo '#####################################################' >&3
        echo "$@" >&3
}

# 
echolog() {
        echo "`date_ymdhms` : $@" >> W/.tests.errors.txt
        echo3 Last errors listed in W/.tests.errors.txt
}

run_test() {
        echo3 "#### $tests_count $1"
	setxon
	# do not run anything between the two following instructions
        $1; run_test_status=$?
	# now you can run
	setxback 2> /dev/null
        if test x"$run_test_status" = x"0"; then
                echo "$1 passed"
        else
                echo3 "$1 failed"
        fi
        return $run_test_status
}

setxon() {
	if ! { echo $-|grep x ; } ; then
		#echo 'set -x was off'
		setx_restore_cmd='set +x'
		set -x
	else
		echo 'set -x already on'
		setx_restore_cmd=""
	fi 
}

setxback() {
        $setx_restore_cmd
}

run_tests() {
        for t in "$@"; do
                tests_count=`expr 1 + $tests_count`
                #
                if ! run_test "$t"; then
                        tests_failed_count=`expr 1 + $tests_failed_count`
                        tests_failed_list="$tests_failed_list $t"
                fi
                sleep 0
        done
        if test 0 -eq $tests_failed_count; then
                echo3 "ALL $tests_count TESTS SUCCESSFUL"
                echolog "ALL $tests_count TESTS SUCCESSFUL"
                return 0
        else
                # At least one failed
                echo3 "FAILED $tests_failed_count/$tests_count TESTS: $tests_failed_list"
                echolog  "FAILED $tests_failed_count/$tests_count TESTS: $tests_failed_list"
                return 1
        fi
}


#### Variable definitions

tests_count=0
tests_failed_count=0

##### The tests functions

perl_syntax() {
        $CMD_PERL -c ./imapsync
}


no_args() {
        $CMD_PERL ./imapsync
}

# list of accounts on petite :

# mailboxes toto -> titi used on first_sync()

# mailboxes tata -> titi used on ll()
# mailboxes tata -> titi on most ll_*() tests

# mailbox tete@est.belle used on big folder size tests:
#                      huge_folder()
#                      huge_folder_sizes_only()
#                      dprof()

# mailbox big1 big2 used on bigmail message tests
#                      ll_bigmail()
#                      ll_memory_consumption

# mailboxes toto -> delme -> delme used on ll_delself

sendtestmessage() {
    email=${1:-"tata"}
    rand=${2:-"`pwgen 16 1`"}
    mess='test: '"$rand"
    cmd="echo $mess""| mail -s '""$mess""' $email"
    echo $cmd
    eval "$cmd"
}

sendtestmessage_titi() {
    email=${1:-"titi"}
    rand=${2:-"`pwgen 16 1`"}
    mess='test: '"$rand"
    cmd="echo $mess""| mail -s '""$mess""' $email"
    echo $cmd
    eval "$cmd"
}


can_send() {

    # no send at all
    #return 1

    test X`hostname` = X"petite" && return 0;
    test X`hostname` = X"plume" && return 0;
    test X`hostname` = X"vadrouille" && return 0;
    return 1
}

at_home() {
    test X`hostname` = X"petite" && return 0;
    return 1
}


zzzz() {
        $CMD_PERL -V

}

set_return_code_variables()
{
# Copy from imapsync 
        EX_OK=0                      #/* successful termination */
        EX_USAGE=64                  #/* command line usage error */
        EX_NOINPUT=66                #/* cannot open input */
        EX_UNAVAILABLE=69            #/* service unavailable */
        EX_SOFTWARE=70               #/* internal software error */
        
        EXIT_CATCH_ALL=1             # Any other error
        
        EXIT_BY_SIGNAL=6
        EXIT_BY_SIGQUIT=131 # 128+3
        EXIT_BY_SIGKILL=137 # 128+9
        EXIT_BY_SIGTERM=143 # 128+15
        
        EXIT_BY_FILE=7
        EXIT_PID_FILE_ERROR=8
        
        EXIT_CONNECTION_FAILURE=10
        EXIT_CONNECTION_FAILURE_HOST1=101
        EXIT_CONNECTION_FAILURE_HOST2=102
        EXIT_TLS_FAILURE=12
        EXIT_AUTHENTICATION_FAILURE=16
        EXIT_AUTHENTICATION_FAILURE_USER1=161
        EXIT_AUTHENTICATION_FAILURE_USER2=162
        EXIT_SUBFOLDER1_NO_EXISTS=21
        
        EXIT_WITH_ERRORS=111
        EXIT_WITH_ERRORS_MAX=112
        EXIT_OVERQUOTA=113
        EXIT_ERR_APPEND=114
        EXIT_ERR_FETCH=115
        EXIT_ERR_CREATE=116
        EXIT_ERR_SELECT=117
        EXIT_TRANSFER_EXCEEDED=118
        EXIT_ERR_APPEND_VIRUS=119
        EXIT_ERR_FLAGS=120
        
        EXIT_TESTS_FAILED=254        # Like Test::More API
}


# general tests start

option_version() {
        $CMD_PERL ./imapsync --version
}


option_tests() {
        $CMD_PERL ./imapsync --tests
}

option_tests_in_var_tmp_sub() {
	( 
	mkdir -p /var/tmp/imapsync_tests
	cd /var/tmp/imapsync_tests
        /g/public_html/imapsync/imapsync --tests
	)
}

option_tests_in_var_tmp() {
	( 
	cd /var/tmp/
        /g/public_html/imapsync/imapsync --tests
	)
}

option_testsdebug() {
        $CMD_PERL ./imapsync --testsdebug
}

option_releasecheck() {
        $CMD_PERL ./imapsync --help --releasecheck | egrep 'This imapsync.*local.*official'
}

option_noreleasecheck() {
        ! { $CMD_PERL ./imapsync --help --noreleasecheck | egrep 'This imapsync.*local.*official' ; }
}


option_bad_delete2() {
	$CMD_PERL ./imapsync --delete 2 --blabla
        test "$?" = "$EX_USAGE"
}

option_extra_arguments() {
	$CMD_PERL ./imapsync --testslive blabla
        test "$?" = "$EX_USAGE"
}

option_extra() {
        (
        mkdir -p W/tmp/tests/options_extra/ || return 1
        cd  W/tmp/tests/options_extra/ || return 1
        echo '--debugimap' > options_extra.txt
        test -f ../../../../imapsync
	../../../../imapsync --testslive
        test "$?" = "$EX_OK"
        )
        pwd
}


passwords_masked() {
	$CMD_PERL ./imapsync --host1 boumboum --password1 secret --justbanner | grep MASKED
}

passwords_not_masked() {
	$CMD_PERL ./imapsync --host1 boumboum --password1 secret --justbanner --showpasswords| grep secret
}

passwords_dollar() {
	$CMD_PERL ./imapsync --host1 boumboum --user1 ee --password1 '$secret' --host2 boumboum --user2 ee --password2 '$secret' --showpasswords
}

passwords_parenthese() {
	#$CMD_PERL ./imapsync --host1 $HOST1 --user1 ee --password1 '( secret' --host2 $HOST2 --user2 ee --password2 '(secret' --showpasswords --debugimap1
	$CMD_PERL ./imapsync --host1 $HOST1 --user1 ee --password1 'secret )' --host2 $HOST2 --user2 ee --password2 '(secret' --showpasswords --debugimap1
}

passfile1_noexist() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 /noexists \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi 
	 test "$?" = "$EX_NOINPUT"
}

passfile2_noexist() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata  \
         --host2 $HOST2 --user2 titi \
         --passfile2 /noexists
	 test "$?" = "$EX_NOINPUT"
}

ll_showpasswords() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --password1 'ami\"seen' \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
	 --justlogin --showpasswords --debugimap1 
}


ll_dry() 
{
# The first is to create INBOX.dry on host2
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX --f1f2 INBOX=INBOX.dry --justfolders

        time $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX --f1f2 INBOX=INBOX.dry --dry
}

ll_dry_nodry1() 
{
        time $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX --f1f2 INBOX=INBOX.dry --dry --nodry1
}

ll_dry_maxage() 
{
        time $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX --f1f2 INBOX=INBOX.dry --dry --maxage 7
}


# In mandatory_tests
ll_justhost1()
{
        $CMD_PERL  ./imapsync --host1 $HOST2
}

# In mandatory_tests
ll_justhost2()
{
        $CMD_PERL  ./imapsync --host2 $HOST2
}


# In mandatory_tests
testslive() {
        $CMD_PERL ./imapsync --testslive
}

# In mandatory_tests
testslive6() {
        $CMD_PERL ./imapsync --testslive6
}


first_sync_dry() {
        $CMD_PERL ./imapsync \
            --host1 $HOST1 --user1 toto \
            --passfile1 ../../var/pass/secret.toto \
            --host2 $HOST2 --user2 titi \
            --passfile2 ../../var/pass/secret.titi \
            --dry
}

first_sync() {
        $CMD_PERL ./imapsync \
            --host1 $HOST1 --user1 toto \
            --passfile1 ../../var/pass/secret.toto \
            --host2 $HOST2 --user2 titi \
            --passfile2 ../../var/pass/secret.titi
}


ll() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi 
}

ll_diff_log_stdout_debugssl() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --justlogin --debugssl 4 \
         --logfile ll_diff_log_stdout_debugssl_1.txt 2>&1 \
         | tee LOG_imapsync/ll_diff_log_stdout_debugssl_2.txt
         echo 
         diff LOG_imapsync/ll_diff_log_stdout_debugssl_1.txt LOG_imapsync/ll_diff_log_stdout_debugssl_2.txt
}



ll_INBOX() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX
}

ll_daily_digest() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST1 --user2 tata \
         --passfile2 ../../var/pass/secret.tata \
         --folder INBOX --dry --nodry1 --maxage 5 \
         --truncmess 1000 --debugcontent --f1f2 INBOX=INBOX.Fake \
         | egrep 'From:|To:|Subject:|Date:|=====|msg '
}



ll_acl() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX.few_emails --syncacl # --debugimap # --dry
}

l_office365_acl()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --folder INBOX.few_emails --syncacl --dry --debugimap
}



ll_namespace_debugimap() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --debugimap1 --justfolderlists
}


ll_host_sanitize() {
        $CMD_PERL  ./imapsync \
         --host1 " local /host " --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 ' loc alhost/    ' --user2 titi \
         --passfile2 ../../var/pass/secret.titi --justlogin 
}


ll_skipcrossduplicates() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --skipcrossduplicates --debugcrossduplicates
}



ll_append_debugimap() {
        sendtestmessage
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
	 --folder INBOX --maxage 1 --debugimap2 --nofoldersizes
}


ll_diff() {
        # sendtestmessage        
        CMD_IMAPSYNC=./imapsync_old ll_tee LOG_imapsync/ll_diff_1.txt
        # sendtestmessage
        CMD_IMAPSYNC=./imapsync     ll_tee LOG_imapsync/ll_diff_2.txt
         
         diff LOG_imapsync/ll_diff_1.txt LOG_imapsync/ll_diff_2.txt
}


ll_tee() {
        logfile=${1:-"LOG_imapsync/ll_tee.txt"}
         $CMD_PERL  $CMD_IMAPSYNC  \
         --host1 $HOST1 --user1 tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX.few_emails --password1 wrong | tee $logfile
#         --passfile1 ../../var/pass/secret.tata \
}

ll_minsize()
{
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --minsize 1000000 --folder INBOX
}

ll_nosearch()
{
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 nosearch \
         --passfile1 ../../var/pass/secret.nosearch \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi 
}

ll_search_larger() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
		 --search 'LARGER 1000' --folder INBOX
}

ll_search_keyword() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --search 'KEYWORD NonJunk' --folder INBOX.flagsetSeen --debugflags --debugimap1 
}




ll_maxsize() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
		 --maxsize 1000 --folder INBOX
}

ll_search_smaller() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
		 --search 'SMALLER 1000' --folder INBOX
}

kk_simulong() {
        $CMD_PERL  ./imapsync \
         --testslive --simulong 30
}

# In mandatory_tests
ll_sigreconnect_INT() { 
        ( $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --sigreconnect INT  --simulong 30 \
         --pidfile /tmp/imapsync_tests_ll_sigreconnect_INT.pid 
         echo status code when killing itself: $? # status code when killing itself?
         ) &
         echo ; sleep 2; echo ; 
         kill -INT `head -1 /tmp/imapsync_tests_ll_sigreconnect_INT.pid`
         echo ; sleep 3; echo ; 
         kill -INT `head -1 /tmp/imapsync_tests_ll_sigreconnect_INT.pid`
         echo ; sleep 3; echo ; 
         kill -INT `head -1 /tmp/imapsync_tests_ll_sigreconnect_INT.pid`
         sleepenh 0.1
         kill -INT `head -1 /tmp/imapsync_tests_ll_sigreconnect_INT.pid`
         wait
}

ll_sigreconnect_CACA() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --sigreconnect CACA  --simulong 30
}

ll_sigreconnect_none() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --sigreconnect ''  --simulong 30
}

ll_sigignore_INT() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --sigignore 'INT'  --simulong 10
}

ll_sigignore_TERM() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --sigignore 'TERM'  --simulong 10
}

# ABORT tests

# In mandatory_tests
ll_abort_pidfile_no_exist()
{
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --abort --pidfile /noexist \
         --logfile ll_abort_pidfile_no_exist.log
         grep 'Can not read pidfile /noexist' LOG_imapsync/ll_abort_pidfile_no_exist.log
}

# In mandatory_tests
ll_abort_noprocess()
{
# The process does not exist so the pidfile is removed so the abort is not done
# and that is ok.
        echo 99998 > /tmp/imapsync_fake.pid
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
        --abort --pidfile /tmp/imapsync_fake.pid \
        --logfile ll_abort_noprocess.log
        grep 'Removing old /tmp/imapsync_fake.pid since its PID 99998 is not running anymore' LOG_imapsync/ll_abort_noprocess.log
}

# In mandatory_tests
ll_abort_not_a_pid_number()
{
        echo 12345678 > /tmp/imapsync_fake.pid
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
        --abort --pidfile /tmp/imapsync_fake.pid \
        --logfile ll_abort_not_a_pid_number.log
        grep 'pid 12345678 in /tmp/imapsync_fake.pid is not a pid number' LOG_imapsync/ll_abort_not_a_pid_number.log
}



# In mandatory_tests
ll_abort_basic()
{ 
        rm -f LOG_imapsync/imapsync_abortme.log
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --pidfile /tmp/imapsync_abortme.pid \
        --logfile imapsync_abortme.log --simulong 4 &
        
        pid_imapsync_abortme=$!
        sleep 2

        # --abort send QUIT signal 
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --abort --pidfile /tmp/imapsync_abortme.pid \
        --logfile imapsync_aborter.log
        
        egrep 'Process PID .* ended.' LOG_imapsync/imapsync_aborter.log || return 1 

        wait $pid_imapsync_abortme
        STATUS_pid_imapsync_abortme="$?"
        #test "$?" = "$EXIT_BY_SIGNAL" || return 1
        test "$STATUS_pid_imapsync_abortme" = "$EXIT_BY_SIGQUIT" || test "$STATUS_pid_imapsync_abortme" = "$EXIT_BY_SIGKILL" || return 1
        grep 'Killing myself with signal QUIT' LOG_imapsync/imapsync_abortme.log || return 1
}

# In mandatory_tests
ll_abort_byfile_hand_made()
{
        rm -f LOG_imapsync/imapsync_abortme.log
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --pidfile /tmp/ll_abort_byfile_hand_made.pid --pidfilelocking \
        --logfile ll_abort_byfile_hand_made.log --simulong 4 &

        pid_imapsync_background=$!

        sleep 4
        touch "/tmp/ll_abort_byfile_hand_made.pidabort$pid_imapsync_background"
        wait $pid_imapsync_background
        test "$?" = "$EXIT_BY_FILE" || return 1
        ! test -f "/tmp/ll_abort_byfile_hand_made.pidabort$pid_imapsync_background" || return 1
}

# In mandatory_tests
ll_abort_byfile_imapsync_made()
{
        rm -f LOG_imapsync/ll_abort_byfile_imapsync_made.log
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --pidfile /tmp/ll_abort_byfile_imapsync_made.pid --pidfilelocking \
        --logfile ll_abort_byfile_imapsync_made.log --simulong 6 --justbanner &

        pid_imapsync_background_2=$!

        sleep 3

        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --pidfile /tmp/ll_abort_byfile_imapsync_made.pid --pidfilelocking \
        --logfile ll_abort_byfile_imapsync_made_aborter.log --abortbyfile


        wait $pid_imapsync_background_2
        test "$?" = "$EXIT_BY_FILE" || return 1
        ! test -f "/tmp/imapsync_abortme_byfile.pidabort$pid_imapsync_background_2" || return 1
}

# In mandatory_tests
ll_abort_byfile_normal_run()
{
        rm -f LOG_imapsync/ll_abort_byfile_normal_run.log
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --pidfile /tmp/ll_abort_byfile_normal_run.pid --pidfilelocking \
        --logfile ll_abort_byfile_normal_run.log --folder INBOX &

        pid_imapsync_background_3=$!

        sleep 3

        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --pidfile /tmp/ll_abort_byfile_normal_run.pid --pidfilelocking \
        --logfile ll_abort_byfile_normal_run_aborter.log --abortbyfile


        wait $pid_imapsync_background_3
        test "$?" = "$EXIT_BY_FILE" || return 1
        ! test -f "/tmp/imapsync_abortme_byfile.pidabort$pid_imapsync_background_3" || return 1
}



# In mandatory_tests
ll_abort_cgi_context_tail() {
# --tail mechanism will not be executed because --pidfile is not already created when tail is called.
        rm -f LOG_imapsync/imapsync_abortme.log
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --pidfile /tmp/ll_abort_cgi_context_tail.pid --pidfilelocking --tail \
        --logfile ll_abort_cgi_context_tail.log --simulong 4 &
        
        sleep 2

# --tail will be ignored because of --abort 
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --abort --pidfile /tmp/ll_abort_cgi_context_tail.pid --pidfilelocking --tail \
        --logfile ll_abort_cgi_context_tail_aborter.log
        
        egrep 'Process PID .* ended.' LOG_imapsync/ll_abort_cgi_context_tail_aborter.log  || return 1
        grep 'Killing myself with signal QUIT' LOG_imapsync/ll_abort_cgi_context_tail.log || return 1
}

# In mandatory_tests
ll_abort_no_pidfile_option() {
        # The final grep has to be fresh
        rm -f LOG_imapsync/ll_abort_no_pidfile_option.log
        
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --logfile ll_abort_no_pidfile_option.log  &
        
        sleep 10

        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --abort  \
        --logfile ll_abort_no_pidfile_option_aborter.log
        
        
        egrep 'Process PID .* ended.' LOG_imapsync/ll_abort_no_pidfile_option_aborter.log || return 1

        grep  'Killing myself with signal QUIT' LOG_imapsync/ll_abort_no_pidfile_option.log || return 1
}


abort_tests()
{
        ll_abort_pidfile_no_exist \
        && ll_abort_noprocess \
        && ll_abort_not_a_pid_number \
        && ll_abort_basic \
        && ll_abort_cgi_context_tail \
        && ll_abort_no_pidfile_option \
        && ll_abort_byfile_hand_made \
        && ll_abort_byfile_imapsync_made \
        && ll_abort_byfile_normal_run

}

ll_simulong() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --justbanner --simulong 5
}


ll_nouid1() {
        can_send && sendtestmessage
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --nouid1 --folder INBOX # --debugimap1
}



ll_eta() {
        can_send && sendtestmessage
        can_send && sendtestmessage
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
	 --folder INBOX
}

ll_final_diff() {
        can_send && sendtestmessage
        can_send && sendtestmessage
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
	 --folder INBOX --f1f2 INBOX=INBOX.final_diff --maxage 30 
}

ll_with_flags_errors() {
        can_send && sendtestmessage
        can_send && sendtestmessage
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --maxage 300 \
        --regexflag 's/.*/PasGlop \\PasGlopRe/' --errorsmax 5
        test "$EXIT_ERR_FLAGS" = "$?"
}



ll_errorsmax() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
	 --nofoldersizes --folder INBOX.errors --regexflag 's/.*/PasGlop \\PasGlopRe/' --errorsmax 5 \
         | grep 'Maximum number of errors 5 reached'
	 #--pipemess 'grep lalalala' --nopipemesscheck --dry  --debugcontent --debugflags
         #test "$EXIT_WITH_ERRORS_MAX" = "$?" # no longer used since errors classification
         #test "$EXIT_ERR_FLAGS" = "$?"
}

ll_debug()
{
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --debug
}

ll_debugcontent() {
        can_send && sendtestmessage
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
	 --debugcontent --maxage 1 --folder INBOX --dry --nodry1 
}

ll_debug_FETCH_BODY() {
        #can_send && sendtestmessage
        $CMD_PERL  ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --debugimap1 --maxage 1 --folder INBOX --dry --nodry1 
}




ll_debugmemory() {
        sendtestmessage
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
	 --debugmemory --nofoldersizes --folder INBOX
}

ll_justfolderlists() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --checkselectable   --justfolderlists
}


ll_checkselectable() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --checkselectable --debugimap1  --justfolderlists \
        | grep 'is selectable'
}

ll_nocheckselectable() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --nocheckselectable --justfolderlists \
        | grep 'Not checking that .*wanted folders are selectable' 
}

ll_checkselectable_nb_folders() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --justfolderlists | grep 'Not checking that .* wanted folders are selectable'
}
        
ll_checkfoldersexist() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --checkfoldersexist --debug  --justfolderlists \
        | grep -i 'checking' 
}

ll_nocheckfoldersexist()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --nocheckfoldersexist --justfolderlists \
        | grep -i 'Not checking that wanted folders exist'
}





ll_nofoldersizes()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --nofoldersizes --folder INBOX
}

ll_nofoldersizes_foldersizesatend() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --nofoldersizes --foldersizesatend --folder INBOX
}


pidfile_well_removed() {
                $CMD_PERL ./imapsync \
                --justbanner \
                --pidfile /var/tmp/imapsync.pid
                test "$?" = "$EX_OK" || return 1
                ! test -f /var/tmp/imapsync.pid
}

pidfile_bad() {
        $CMD_PERL ./imapsync \
                --justbanner \
                --pidfile /var/tmp/noexist/imapsync.pid
                test "$?" = "$EXIT_PID_FILE_ERROR"
}


ll_skipcrossduplicates_usecache() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --skipcrossduplicates --usecache
        test "$?" = "$EX_USAGE"
}



test_tail() {
        $CMD_PERL ./imapsync \
                --justbanner --simulong 15 \
                --pidfile /var/tmp/imapsync_tail_tests.pid \
                --pidfilelocking &
        
        sleep 1
        
        $CMD_PERL ./imapsync \
                --justbanner \
                --pidfile /var/tmp/imapsync_tail_tests.pid \
                --pidfilelocking --tail 

}

ll_pidfilelocking()  {
                rm -f /var/tmp/imapsync_test_pidfilelocking.pid

                echo ll_pidfilelocking 01 lockfile is not previously there
                $CMD_PERL ./imapsync --justbanner \
                --pidfile /var/tmp/imapsync_test_pidfilelocking.pid \
                --pidfilelocking || return 1

                echo ll_pidfilelocking 02 lockfile normally removed
                ! test -f /var/tmp/imapsync_test_pidfilelocking.pid || return 1

                echo ll_pidfilelocking 03 lockfile created before
                touch /var/tmp/imapsync_test_pidfilelocking.pid || return 1
                
                echo ll_pidfilelocking 04  lockfile already there but not with a PID number
                ! $CMD_PERL ./imapsync --justbanner \
                --pidfile /var/tmp/imapsync_test_pidfilelocking.pid \
                --pidfilelocking  || return 1

                echo ll_pidfilelocking 05 lockfile still there
		test -f /var/tmp/imapsync_test_pidfilelocking.pid || return 1
                
                echo ll_pidfilelocking 06 filling lockfile with 33333 
                echo 33333 > /var/tmp/imapsync_test_pidfilelocking.pid
                
                echo ll_pidfilelocking 07 lockfile already there with fake PID in it, imapsync will remove it and generate a new one.
		$CMD_PERL ./imapsync --justbanner \
                --pidfile /var/tmp/imapsync_test_pidfilelocking.pid \
                --pidfilelocking || return 1
                
                echo ll_pidfilelocking 08 lockfile should be removed now
                ! test -f /var/tmp/imapsync_test_pidfilelocking.pid || return 1
}


justbanner() {    
                $CMD_PERL ./imapsync \
                --justbanner
}

nomodules_version() {    
                $CMD_PERL ./imapsync \
                --justbanner \
                --nomodules_version
}


ll_ask_password() {
                { 
		sleep 2; cat ../../var/pass/secret.tata; 
		sleep 2; cat ../../var/pass/secret.titi; 
		} | \
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --host2 $HOST2 --user2 titi \
                --justlogin
}

ll_env_password() {
                set +x
                IMAPSYNC_PASSWORD1=`cat ../../var/pass/secret.tata` \
                IMAPSYNC_PASSWORD2=`cat ../../var/pass/secret.titi` \
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --host2 $HOST2 --user2 titi --passfile2 ../../var/pass/secret.titi \
                --justlogin
}


ll_authmech_PREAUTH() {
                # No PREAUTH on my box
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata --authmech1 PREAUTH \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --debugimap1
                test "$?" = "$EXIT_AUTHENTICATION_FAILURE"
}





ll_unknow_option() {
                ! $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --unknow_option
}


ll_timeout() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --timeout 4.99 --justlogin
}

ll_timeout1_timeout2() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --timeout1 1.99 --timeout2 1.95 --justlogin
}

ll_timeout_timeout1() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --timeout1 5 --timeout 4 --justlogin
}


ll_timeout_very_small() {
                ! $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --timeout 0.001 --nossl1 --nossl2 --notls1 --notls2 --justlogin
}


ll_folder() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop --folder INBOX.Trash 
}

ll_backstar() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder 'INBOX.backstar\*' --dry --justfolders --debugimap1 --regextrans2 's#\\|\*#_#g'
}

ll_star() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder 'INBOX.star*' --justfolders --debugimap
}

ll_star_ch() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folderrec 'INBOX.Z_ch' --justfolders --debugimap 
}

ll_tr() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --dry --justfolders --include a --regextrans2 'tr/a/_/' 
}

ll_tr_delete() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --dry --justfolders --folder INBOX.lalala --regextrans2 'tr/a//d' 
}


ll_regextrans2_d() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --dry --justfolders --regextrans2 's,INBOX\.,,'
}


lks_trailing_space() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 ks.lamiral.info --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --justfolders --ssl1 --ssl2
}


lks_doublequote() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 ks.lamiral.info --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --folder 'INBOX."uni"' --debugimap2 --nofoldersizes --justfolders --ssl1 --ssl2
}

lks_doublequote_rev() {
                $CMD_PERL ./imapsync \
                --host1 ks.lamiral.info  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --foldersizes --ssl1 --ssl2 --justfolders 
}

ksks_password_doublequote() {
        $CMD_PERL ./imapsync \
                --host1 ks.lamiral.info  --user1 test1 \
                --password1 'secret1' \
                --host2 ks.lamiral.info --user2 test1 \
                --password2 '"secret1"' \
                --debugimap --justlogin --showpasswords
}

ksks_empty_test1()
{
        $CMD_PERL ./imapsync \
                --host1 test1.lamiral.info  --user1 test1 \
                --password1 'secret1' \
                --host2 test1.lamiral.info --user2 test1 \
                --password2 'secret1' \
                --delete1 --delete1emptyfolders
}

ksks_init_test1()
{
        $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 test1.lamiral.info --user2 test1 \
                --password2 'secret1' \
                --folder INBOX.init --f1f2 INBOX.init=INBOX \
                --folderrec 'INBOX.init'
}

# In mandatory_tests
ksks_reset_test1()
{
        ksks_empty_test1
        ksks_init_test1
}

ksks_empty_test2() {
        $CMD_PERL ./imapsync \
                --host1 test2.lamiral.info  --user1 test2 \
                --password1 'secret2' \
                --host2 test2.lamiral.info --user2 test2 \
                --password2 'secret2' \
                --delete1 --delete1emptyfolders
}




ll_folder_noexist() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.noexist --folder INBOX.noexist2
}


ll_folder_mixfolders() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --mixfolders --justfolders --nofoldersizes
}



# Way to check it each time:
# sh -x tests.sh ll_folder_create ll_delete2folders

# In mandatory_tests
ll_folder_create() { 
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop --regextrans2 's/yop/new.nested.yop/' \
		--justfolders
}

# In mandatory_tests
ll_folder_create_INBOX_Inbox() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --regextrans2 's/INBOX/Inbox/' \
		--justfolders --nofoldersizes
}

ll_folder_create_backslash_backslash() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap.yip --regextrans2 's/yop/newyop/' \
                --sep2 '\\' \
		--justfolders --nofoldersizes --dry 
}

ll_folder_domino() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap.yip --regextrans2 's/yop/newyop/' \
                --sep2 '\' --prefix2 '' --prefix1 '' \
		--regextrans2 's,^Inbox\\(.*),$1,i' \
		--justfolders  --dry --debug 
}

ll_folder_domino_sub() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap.yip --regextrans2 's/yop/newyop/' \
                --sep2 '\' --prefix2 '' \
		--subfolder2 'OLDBOX' \
		--justfolders  --dry --debug 
}

# In mandatory_tests
ll_domino2() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap.yip --regextrans2 's/yop/newyop/' \
                --domino2 \
		--subfolder2 'OLDBOX' \
		--justfolders  --dry --debug 

}

# In mandatory_tests
ll_domino1_domino2() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap.yip --regextrans2 's/yop/newyop/' \
                --domino1 --domino2 \
		--subfolder2 'OLDBOX' \
		--justfolders  --dry
}




ll_oneemail() {
	$CMD_PERL ./imapsync \
	--host1 $HOST1  --user1 tata \
	--passfile1 ../../var/pass/secret.tata \
	--host2 $HOST2 --user2 titi \
	--passfile2 ../../var/pass/secret.titi \
	--folder INBOX.oneemail
}

ll_debugimap() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.oneemail --debugimap --justlogin
}

ll_few_emails() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.few_emails
}

ll_few_emails_dev() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.few_emails --nofoldersizes
}

ll_pipemess() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.few_emails --pipemess 'cat' --pipemess 'reformime -r7'
                cmd_status=$?
		echo "sudo rm -rf /home/vmail/titi/.few_emails/"
                return $cmd_status
}

ll_pipemess_catcat() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.few_emails --pipemess '(cat|cat)' --pipemess 'reformime -r7'
                cmd_status=$?
		echo "sudo rm -rf /home/vmail/titi/.few_emails/"
                return $cmd_status
}

ll_pipemess_nocmd() {
		
                ! $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.few_emails --pipemess 'nocat'
		
		echo "sudo rm -rf /home/vmail/titi/.few_emails/"
}

ll_pipemess_false() {
		
                ! $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.few_emails --pipemess '/bin/false' --nopipemesscheck 
		
		echo "sudo rm -rf /home/vmail/titi/.few_emails/"
}

ll_pipemess_true() {
		
                ! $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.few_emails --pipemess '/bin/true' 
		
		echo "sudo rm -rf /home/vmail/titi/.few_emails/"
}


ll_size_null() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.size_null
}

# In mandatory_tests
ll_noheader() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.few_emails --useheader '' --debug
}

# In mandatory_tests
ll_noheader_force() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.few_emails \
		--useheader '' \
		--skipheader 'Message-Id|Date'
}

ll_addheader() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.addheader --delete2  
                
                # destination should be empty
                ! ls /home/vmail/titi/.addheader/cur/* || return 1
                
                
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.addheader --delete2  --addheader
                
                # Now it should be not empty
                ls /home/vmail/titi/.addheader/cur/* || return 1
}

ll_addheader_minage() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.addheader --delete2  
                
                # destination should be empty
                ! ls /home/vmail/titi/.addheader/cur/* || return 1
                
                
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.addheader --delete2  --addheader --minage 365 --debugimap
                
                # Now it should be not empty
                ls /home/vmail/titi/.addheader/cur/* || return 1
}



ll_usecachemaxage() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --useuid --maxage 3
}



ll_folderrec() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folderrec INBOX.yop  --justfolders
}

ll_folderrec_INBOX() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folderrec INBOX  --justfolders
}

ll_folderrec_star() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folderrec 'INBOX.yop.*'  --justfolders
}

ll_change_blank() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders --nofoldersizes --folder "INBOX. blanc_begin" --regextrans2 "s,(\.|^) +,\$1,g"
}




ll_folderrec_blank_bug() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folderrec "INBOX.blanc  " 
}

ll_folderrec_blank_bug_2() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folderrec "INBOX.blanc" 
}

ll_folderrec_blank_bug_3() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folderrec '"INBOX.blanc  "'
}



ll_buffersize() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --buffersize 8 
}

ll_automap() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justautomap --automap  
}

ll_justautomap() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justautomap 
}


l_ks_automap() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 test2.lamiral.info --user2 test2 \
                --password2 secret2 \
                --justautomap --automap 
}

l_gmail_automap() {

                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justautomap --automap --dry 
}

gmail_l_automap() {

                $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justautomap --automap --dry 
}



ll_justfolders() {
        $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  
        echo "sudo rm -rf /home/vmail/titi/.new_folder/"
}


ll_create_folder_New1()
{
        ./W/learn/create_folder localhost tata `cat ../../var/pass/secret.tata` INBOX.New1 INBOX.New1.New1 INBOX.New1.New1.New1
        $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders --include New1 --folderfirst INBOX.New1.New1
}

ll_delete_folder_New1()
{
        $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --include New1 --folderfirst INBOX.New1.New1 --delete1emptyfolders --delete1 
        
}

ll_create_folder_encoding_accent()
{
        ./W/learn/create_folder localhost tata `cat ../../var/pass/secret.tata` INBOX.New1 'INBOX.New1.E&AwE-le&AwE-ments envoye&AwE-s' 'INBOX.New1.&AMk-l&AOk-ments envoy&AOk-s'
        $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders --include New1 
}


ll_create_folder_encoding_accent_365()
{
        #./W/learn/create_folder localhost tata `cat ../../var/pass/secret.tata`  'INBOX.E&AwE-le&AwE-ments envoye&AwE-s' 'INBOX.&AMk-l&AOk-ments envoy&AOk-s'
        $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap-mail.outlook.com --user2 gilles.lamiral@outlook.com \
                --passfile2 ../../var/pass/secret.outlook.com \
                --justfolders --include 'ments envoy' --automap --exclude New1
}





ll_justfolders_delete1emptyfolders() {
        ./W/learn/create_folder localhost tata `cat ../../var/pass/secret.tata` INBOX.Empty INBOX.Empty.Empty INBOX.Empty.Empty.Empty
        $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  --delete1emptyfolders --include Empty --folder INBOX --folderfirst INBOX.Empty.Empty --foldersizes 
}


ll_delete1_delete1emptyfolders() {
        ./W/learn/create_folder localhost tata `cat ../../var/pass/secret.tata` INBOX.Empty INBOX.Empty.Empty INBOX.Empty.Empty.Empty
        $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --delete1emptyfolders --delete1 --include Empty --folder INBOX --folderfirst INBOX.Empty.Empty --dry
}



ll_justfolders_skipemptyfolders()  {
        $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  --skipemptyfolders \
                --folder INBOX.empty --folder INBOX.notempty 
}




ll_justfolders_folderfirst_noexist() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --nofoldersizes --justfolders --folderfirst noexist --debug
}



ll_justfolders_foldersizes()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders
                echo "sudo rm -rf /home/vmail/titi/.new_folder/"
}


# In mandatory_tests
ll_delete2foldersonly_dry()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  --nofoldersizes \
                --subfolder2 NEW --delete2foldersonly NEW --dry
}

# In mandatory_tests
ll_delete2foldersonly_subfolder2()
{
./W/learn/create_folder localhost titi `cat /g/var/pass/secret.titi` INBOX.NEW_2
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  --nofoldersizes \
                --subfolder2 NEW_2 \
                --delete2foldersonly NEW_2 --folder INBOX --debug
                # NEW_2 should be still there because of --subfolder2 NEW_2
                test -d /home/vmail/titi/.NEW_2/  || return 1
}

# In mandatory_tests
ll_delete2foldersbutnot()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  --nofoldersizes \
                --delete2foldersbutnot 'm{NEW_2|NEW_3|\[abc\]}' \
		--dry
}

# In mandatory_tests
ll_delete2foldersonly_NEW_3()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  --nofoldersizes \
		--regextrans2 's,^INBOX.oneemail$,INBOX.NEW_3.oneemail,' \
		--regextrans2 's,^INBOX.oneemail2$,INBOX.NEW_3.oneemail2,' 

		test -d /home/vmail/titi/.NEW_3.oneemail/  || return 1
		test -d /home/vmail/titi/.NEW_3.oneemail2/  || return 1

                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  --nofoldersizes \
		--include 'rrrrr' \
                --delete2foldersonly '/^INBOX.NEW_3.oneemail$/'

		! test -d /home/vmail/titi/.NEW_3.oneemail/ || return 1
		test -d /home/vmail/titi/.NEW_3.oneemail2/ || return 1
}

ll_delete2foldersonly_bug() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  --nofoldersizes \
		--include 'rrrrr' \
                --delete2foldersonly '/INBOX.Archive/' --dry
#                --delete2foldersonly '/^INBOX.Archive$/' --dry

}


# In mandatory_tests
ll_delete2folders()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders  --nofoldersizes \
                --delete2folders 

                ! test -d /home/vmail/titi/.NEW_3/ || return 1
}




ll_bug_folder_name_with_blank() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders --fast 
                echo "rm -rf /home/vmail/titi/.bugs/"
}


ll_bug_folder_name_with_backslash() {
# Bug with Mail-IMAPClient-2.2.9
# Fixed using Mail-IMAPClient-3.28
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --fast

#		--folder "INBOX.yop.jj\\kk" 
#		--folder '"INBOX.yop.jj\kk"' --debug --debugimap --regextrans2 's,\\,_,g'
#		--folder "INBOX.yop.jj\\kk" --debug --debugimap1
                echo "sudo rm -rf '/home/vmail/titi/.yop.jj\\kk'"
}



ll_prefix12() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.qqq  \
                --prefix1 INBOX.\
                --prefix2 INBOX. 
}



ll_nosyncinternaldates() {
        can_send && sendtestmessage toto
        $CMD_PERL ./imapsync \
         --host1 $HOST1  --user1 toto \
         --passfile1 ../../var/pass/secret.toto \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX  \
         --nosyncinternaldates  --delete2  
}
# bug:
# $d=""; # no bug with $d=undef
# $imap2->append_string($h2_fold,$string, $h1_flags, $d);
# 3.25 idate  : Sending: 16 APPEND INBOX () "16-Jul-2010 22:09:42 +0200" {428}
# 2.xx idate  : Sending: 62 APPEND INBOX "16-Jul-2010 22:14:00 +0200" {428}
# 3.25 noidate: Sending: 16 APPEND INBOX () "" {428} # Fails: NO IMAP!
# 2.xx noidate: Sending: 62 APPEND INBOX {428}

ll_idatefromheader() {

        # can_send && sendtestmessage

        $CMD_PERL ./imapsync \
         --host1 $HOST1  --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --folder INBOX.oneemail2  \
         --idatefromheader  --debug --dry 
}

ll_idatefromheader_barker() {

        # can_send && sendtestmessage

        $CMD_PERL ./imapsync \
         --host1 $HOST1  --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 imap.europe.secureserver.net --user2 test@alicebarkertest.com \
         --passfile2 ../../var/pass/secret.barker \
         --folder INBOX.oneemail2 --nofoldersizes \
         --debug  --useheader ALL
}




ll_folder_rev() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 titi \
                --passfile1 ../../var/pass/secret.titi \
                --host2 $HOST2 --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --folder INBOX.yop 
}

ll_subscribed()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --subscribed 
}


ll_nosubscribe() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --subscribed --nosubscribe 
}

ll_justconnect() 
{
                $CMD_PERL ./imapsync    \
                --host1 $HOST1 \
                --host2 $HOST2 \
                --justconnect --debugimap
}





ll_justconnect_ipv6()
{
        $CMD_PERL ./imapsync    \
                --host1 "::1" \
                --host2 "::1" \
                --justconnect 
}

ll_justconnect_ipv6_nossl()
{
        $CMD_PERL ./imapsync    \
                --host1 "::1" --nossl1 \
                --host2 "::1" --nossl2 \
                --justconnect 
}

ks_justconnect_ipv6()
{
        $CMD_PERL ./imapsync    \
                --host1 ks2ipv6.lamiral.info \
                --host2 ks2ipv6.lamiral.info \
                --justconnect 
}

ks_justconnect_ipv6_nossl()
{
        $CMD_PERL ./imapsync    \
                --host1 ks2ipv6.lamiral.info --nossl1 \
                --host2 ks2ipv6.lamiral.info --nossl2 \
                --justconnect 
}



ll_justfoldersizes()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --nocheckfoldersexist --nocheckselectable \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes # --folder INBOX
}

ll_justfoldersizes_all_to_INBOX()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --nocheckfoldersexist --nocheckselectable \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --regextrans2 's/.*/INBOX/'
}


ll_justfoldersizes_case_different()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --nocheckfoldersexist --nocheckselectable \
                --justfoldersizes --folder NoExist --folder INBOX --regextrans2 's,^INBOX$,iNbOx,'
}

ll_justfoldersizes_case_different_2()
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --folder INBOX.yop --regextrans2 's,yop,YoP,'
}



ll_justfoldersizes_noexist() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --folder NoExist --folder AnotherNoExist  \
                --nocheckfoldersexist --errorsmax 2
}


ll_reconnect_on_signal_debugimap()
{
# in another terminal:
#
: <<'EOF'
while echo ENTER TO STOP; read a ; do
killall --signal STOP -v -u vmail imapd
echo ENTER to CONT; read a
killall --signal CONT -v -u vmail imapd
done
EOF

        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --debugsleep 3.5 --debugimap 
}

ll_reconnect_on_signal()
{
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi 
}



ll_dev_reconnect_none()
{
# in another terminal:
#
: <<'EOF'
while :; do 
    killall -v -u vmail imapd; 
    RAND_WAIT=`numrandom .1..5i.1`
    echo sleeping $RAND_WAIT
    sleepenh $RAND_WAIT
done
# or 
while read y; do 
    killall -v -u vmail imapd
done
EOF
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --useuid \
                --reconnectretry2 0 --reconnectretry1 0
}

ll_dev_reconnect_one()
{
# in another root terminal:
#
: <<'EOF'
while read y; do 
    killall -v -u vmail imapd
done
EOF
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --useuid \
                --reconnectretry2 1 --reconnectretry1 1
}




ll_dev_reconnect_ssl_tls() 
{
# in another terminal:
#
: <<'EOF'
while :; do 
    killall -v -u vmail imapd; 
    RAND_WAIT=`numrandom .1..5i.1`
    echo sleeping $RAND_WAIT
    sleepenh $RAND_WAIT
done
# or 
while read y; do
    echo ENTER to kill all imapd
    killall -v -u vmail imapd; 
done

EOF
        can_send && sendtestmessage
#        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --ssl1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --tls2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --useuid \
		--delete2
}

ll_dev_reconnect_tls() 
{
# in another terminal:
#
: <<'EOF'
while :; do 
    killall -v -u vmail imapd; 
    RAND_WAIT=`numrandom .1..5i.1`
    echo sleeping $RAND_WAIT
    sleepenh $RAND_WAIT
done
# or 
while read y; do
    echo ENTER to kill all imapd
    killall -v -u vmail imapd; 
done

EOF
        can_send && sendtestmessage
#        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --tls1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --tls2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX --useuid \
		--delete2 --debugsleep 5 --debugimap
}




ll_authmd5() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --authmd5 
}

ll_authmd51() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --authmd51
}

ll_authmd52() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --authmd52
}

ll_noauthmd5() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --noauthmd5 
}


ll_maxage() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 1 --folder INBOX
}

ll_maxage_0() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 0 --folder INBOX
}

ll_maxage_0_float_1min() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 0.0006944 --folder INBOX --noabletosearch
}



ll_minage_0() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --minage 0 --folder INBOX
}

ll_maxage_10000_minage_9999() 
{
	# INTERSECTION: 0 messages
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 10000 --minage 9999 \
	--folder INBOX --justfoldersizes
}

ll_maxage_9999_minage_10000() 
{
	# UNION: all messages
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 9999 --minage 10000 \
	--folder INBOX --justfoldersizes
}

ll_maxage_10000_minage_9999_noabletosearch() 
{
	# INTERSECTION: 0 messages
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 10000 --minage 9999 \
	--folder INBOX --justfoldersizes --noabletosearch
}

ll_maxage_9999_minage_10000_noabletosearch() 
{
	# UNION: all messages
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 9999 --minage 10000 \
	--folder INBOX --justfoldersizes --noabletosearch
}



ll_maxage_10000() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 10000 --folder INBOX
}


ll_maxage_0_debugimap2() 
{
        #can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 0 --folder INBOX --debugimap2 --nofoldersizes
}



ll_search_ALL() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search 'ALL' --folder INBOX
}

ll_search1_NOT_OR_OR_UID()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search1 'NOT OR OR UID 20000 UID 20002 UID 20004' --folder INBOX
}

ll_search1_OR_OR_UID()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search1 'OR OR UID 20000 UID 20002 UID 20004' --folder INBOX
}

ll_search2_NOT_OR_OR_UID()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search2 'NOT OR OR UID 20000 UID 20002 UID 20004' --folder INBOX
}


ll_search_FLAGGED() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search 'FLAGGED' --folder INBOX
}

ll_search_NOT_DELETED() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search 'NOT DELETED' --folder INBOX
}


ll_search_SENTSINCE() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search 'SENTSINCE 11-Jul-2011' --folder INBOX
}

ll_search_BEFORE_delete2_useuid() 
{
        can_send && sendtestmessage titi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search 'BEFORE 29-Sep-2011' --folder INBOX --delete2 --useuid
}

ll_search_SENTBEFORE() 
{
        can_send && sendtestmessage titi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search 'SENTBEFORE 31-Dec-2013' --folder INBOX --delete2
}

ll_search_SENTSINCE_and_BEFORE() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search 'SENTSINCE 1-Jan-2010 SENTBEFORE 31-Dec-2013' --folder INBOX --delete2 --dry
}

ll_search_SENTSINCE_and_BEFORE_search2() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search 'SENTSINCE 1-Jan-2010 SENTBEFORE 31-Dec-2013' \
	--search2 'ALL' --folder INBOX --delete2
}

ll_search_HEADER_attachment()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search "OR HEADER Content-Disposition attachment HEADER Content-Type multipart/mixed" \
        --folder INBOX
}

ll_search_NOT_HEADER_attachment()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search "NOT OR HEADER Content-Disposition attachment HEADER Content-Type multipart/mixed" \
        --folder INBOX
}


ll_search_HEADER_attachment_multipart() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search "HEADER Content-Type multipart/mixed" \
	--folder INBOX
}

ll_search_NOT_SUBJECT() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search "NOT SUBJECT test:" \
        --folder INBOX
}


ll_search_UNSEEN_SENTSINCE() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --search "UNSEEN SENTSINCE 23-Aug-2015" \
        --folder INBOX --dry
}


ll_search_FROM_TO_CC()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --dry --search 'OR FROM gilles@localhost (OR TO gilles@localhost (CC gilles@localhost))'
}

ll_search_FROM()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --dry --search 'FROM gilles@localhost'
}



ll_maxage_nonew() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 1 --nofoldersizes \
        --folder INBOX.few_emails
}


ll_noabletosearch() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.few_emails --noabletosearch
	# --debugdev --debugimap
}

ll_fetch_hash_set() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --justfoldersizes --noabletosearch --fetch_hash_set '1:*' 
	# --debugdev --debugimap
}

ll_fetch_hash_set_abletosearch() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --justfoldersizes --abletosearch --fetch_hash_set '1:*' 
	# --debugdev --debugimap
}





ll_noabletosearch1() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.few_emails --noabletosearch1 --debugimap
}

ll_noabletosearch2() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.few_emails --noabletosearch2 --debugimap
}


ll_newmessage()
{
        can_send && sendtestmessage
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 1 --folder INBOX --nofoldersizes \
	--debugLIST
}

ll_debugLIST()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --nofoldersizes \
	--debugLIST
}

ll_search_UID()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --nofoldersizes \
	--debugLIST --search1 "UID 10000:20000"
}




ll_exitwhenover() 
{
        sendtestmessage
        sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 1 --folder INBOX --nofoldersizes \
        --exitwhenover 100
        test "$EXIT_TRANSFER_EXCEEDED" = "$?"
}


ll_exitwhenover_noerrorsdump() 
{
        sendtestmessage
        sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --maxage 1 --folder INBOX --nofoldersizes \
        --exitwhenover 100 --noerrorsdump
        test "$EXIT_TRANSFER_EXCEEDED" = "$?"
}






ll_folder_INBOX()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX  --noreleasecheck --usecache --delete2 
}

ll_dry_folder_missing()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX  --dry --regextrans2 "s,^INBOX$,noexit,"
}



ll_maxage_9999() 
{
#        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --justfoldersizes --folder INBOX \
        --maxage 9999 
}

ll_maxlinelength() 
{       
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --maxlinelength 8 --nofoldersizes --folder INBOX
}

ll_maxlinelengthcmd() 
{       
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --maxlinelength 8 --maxlinelengthcmd cat --nofoldersizes --folder INBOX 
}



ll_minmaxlinelength() 
{       
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --minmaxlinelength 1000 --nofoldersizes --folder INBOX
}


ll_maxlinelength_prepa_1()
{
    $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --folderrec INBOX.Junk --foldersizes --justfolders \
        --usecache --tmpdir /var/tmp --minmaxlinelength 8000 --debugmaxlinelength
}

ll_maxlinelength_prepa_2()
{
    $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tete@est.belle \
        --passfile1 ../../var/pass/secret.tete \
        --host2 ks.lamiral.info --user2 tata \
        --passfile2 ../../var/pass/secret.tata \
	--ssl2 \
        --include INBOX.Junk.20 --foldersizes --nojustfolders \
        --useuid --tmpdir /var/tmp --minmaxlinelength 10 --delete2 --nofastio1 --nofastio2
}



ll_maxsize() 
{       
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --maxsize 10 --folder INBOX
}

ll_maxsize_useuid() 
{       
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --maxsize 10 --folder INBOX \
                --useuid --debugcache
}

ll_minsize_useuid() 
{       
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX \
                --useuid --debugLIST --minsize 500 --maxage 1
}




ll_skipsize() 
{
        can_send && sendtestmessage
	$CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --skipsize --folder INBOX.yop.yap 
}

ll_skipheader() 
{
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --useheader ALL \
                --skipheader '^X-.*|^Date' --folder INBOX.yop.yap \
                --debug --dry
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
                --include '^INBOX.yop' 
}

ll_include_include() 
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
		--nofoldersizes \
                --include '^INBOX.yop' --include '^INBOX.' 
}

ll_include_exclude() 
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
		--nofoldersizes \
                --include '^INBOX.yop' --exclude '^INBOX.' 
}



ll_exclude()
{ 
 $CMD_PERL ./imapsync \
 --host1 $HOST1 --user1 tata \
 --passfile1 ../../var/pass/secret.tata \
 --host2 $HOST2 --user2 titi \
 --passfile2 ../../var/pass/secret.titi \
 --exclude '^(?i)INBOX.YOP' --justfolders --nofoldersizes
} 

ll_exclude_2() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --exclude '^INBOX.yop$' --justfolders --nofoldersizes
}

ll_exclude_INBOX() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --exclude '^INBOX' --justfolders --nofoldersizes --dry
}

ll_exclude_blanc_middle() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --exclude '^INBOX.blanc\smiddle' --justfolders --nofoldersizes --dry
}

ll_f1f2_01() 
{
       $CMD_PERL ./imapsync \
       --host1 $HOST1 --user1 tata \
       --passfile1 ../../var/pass/secret.tata \
       --host2 $HOST2 --user2 titi \
       --passfile2 ../../var/pass/secret.titi \
       --justfolders \
       --folder 'INBOX.yop.yap' --f1f2 'INBOX.yop.yap=INBOX/rha/lovely' --f1f2 'lalala=lululu' --debugfolders
        test "$EXIT_ERR_CREATE" = "$?"
}

ll_regextrans2() 
{
       $CMD_PERL ./imapsync \
       --host1 $HOST1 --user1 tata \
       --passfile1 ../../var/pass/secret.tata \
       --host2 $HOST2 --user2 titi \
       --passfile2 ../../var/pass/secret.titi \
       --justfolders \
       --regextrans2 's/yop/yoX/' \
       --folder 'INBOX.yop.yap' --debug
}

ll_add_suffix() 
{
       $CMD_PERL ./imapsync \
       --host1 $HOST1 --user1 tata \
       --passfile1 ../../var/pass/secret.tata \
       --host2 $HOST2 --user2 titi \
       --passfile2 ../../var/pass/secret.titi \
       --justfolders \
       --regextrans2 's,$,\@easterngraphics.com,' \
       --folderrec 'INBOX.yop' --dry --justfolders
}



ll_regextrans2_ucfirst_downcase_last_folder() 
{
# lowercase the last basename part
# [INBOX.yop.YAP] -> [INBOX.yop.Yap] using re 
# [INBOX.yop.YAP]                     -> [INBOX.yop.Yap]                    

# \l          lowercase next char (think vi)
# \u          uppercase next char (think vi)
# \L          lowercase till \E (think vi)
# \U          uppercase till \E (think vi)
# \E          end case modification (think vi)
# \Q          quote (disable) pattern metacharacters till \E

       $CMD_PERL ./imapsync \
       --host1 $HOST1 --user1 tata \
       --passfile1 ../../var/pass/secret.tata \
       --host2 $HOST2 --user2 titi \
       --passfile2 ../../var/pass/secret.titi \
       --justfolders \
       --nofoldersizes \
       --regextrans2 's,(.*)\.(.+)$,$1.\u\L$2\E,' \
       --folder 'INBOX.yop.YAP' --justfolders --debug --dry
}

ll_regextrans2_ucfirst_downcase_all_folders()
{
# lowercase the last basename part
       $CMD_PERL ./imapsync \
       --host1 $HOST1 --user1 tata \
       --passfile1 ../../var/pass/secret.tata \
       --host2 $HOST2 --user2 titi \
       --passfile2 ../../var/pass/secret.titi \
       --justfolders \
       --nofoldersizes \
       --regextrans2 's,([^.]+),\u\L$1\E,g' \
       --folder 'INBOX.yop.YAP' --justfolders --debug --dry
}


ll_regextrans2_slash() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders \
                --nofoldersizes \
                --folder 'INBOX.yop.yap' \
                --sep1 '/' \
                --regextrans2 's,/,_,'

}


ll_regextrans2_dot() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders \
                --folder 'INBOX.yop.yap' \
                --regextrans2 "s,\.,_,g" --dry
}




ll_subfolder2() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders --foldersizesatend \
                --subfolder2 SUB 
}

ll_subfolder1()
{
# reverse of ll_subfolder2
                $CMD_PERL ./imapsync \
                --host1 $HOST2 --user1 titi  \
                --passfile1 ../../var/pass/secret.titi \
                --host2 $HOST1 --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --justfolders  \
                --subfolder1 SUB --dry  
}

ll_subfolder1_INBOX_SUB()
{
# reverse of ll_subfolder2
                $CMD_PERL ./imapsync \
                --host1 $HOST2 --user1 titi  \
                --passfile1 ../../var/pass/secret.titi \
                --host2 $HOST1 --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --justfolders  \
                --subfolder1 INBOX.SUB --dry 
}

ll_subfolder1_DOES_NOT_EXIST() 
{
# --subfolder1 does not exist
                ! $CMD_PERL ./imapsync \
                --host1 $HOST2 --user1 titi  \
                --passfile1 ../../var/pass/secret.titi \
                --host2 $HOST1 --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --justfolders  \
                --subfolder1 DOES_NOT_EXIST --dry  
}



ll_nochildren() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 w00d0310.kasserver.com --user2 m0331832  \
                --passfile2 ../../var/pass/secret.kasserver \
                --folderrec INBOX.A --subfolder2 inferior_top_level
}





ll_regextrans2_remove_space() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders \
                --nofoldersizes \
                --folder 'INBOX.yop.y p' \
                --regextrans2 's, ,,' \
                --dry

}


ll_regextrans2_archive_per_month() 
{
# Bad behavior on Courier
# SENTBEFORE 31-Apr returns nothing
# SENTBEFORE 30 Apr returns messages

		year=2012
		month=Apr
		month_n=04
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --nofoldersizes \
		--search "SENTSINCE 1-$month-$year SENTBEFORE 30-$month-$year" \
                --regextrans2 "s{.*}{INBOX.Archive.$year.$month_n}" 
}


ll_regextrans2_archive_per_year_flat_hard_year() 
{
        year=
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --nofoldersizes \
                --search "SENTSINCE 1-1-$year SENTBEFORE 30-12-2018" \
                --sep2 _ --regextrans2 's{(.*)}{Archive_$1_2018}' --justfolders --dry
}

ll_regextrans2_archive_per_year_flat_variable_year() 
{
        year=2018
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --nofoldersizes \
                --search "SENTSINCE 1-1-$year SENTBEFORE 30-12-$year" \
                --sep2 _ --regextrans2 's{(.*)}{Archive_$1_'"$year}" --justfolders --dry
}





ll_regextrans2_ALLIN() 
{
       $CMD_PERL ./imapsync \
       --host1 $HOST1 --user1 tata \
       --passfile1 ../../var/pass/secret.tata \
       --host2 $HOST2 --user2 titi \
       --passfile2 ../../var/pass/secret.titi \
       --regextrans2 's/.*/INBOX.ALLIN/' \
       --folderrec 'INBOX.yop' --delete2
}

ll_regextrans2_ALLIN_usecache() 
{
       $CMD_PERL ./imapsync \
       --host1 $HOST1 --user1 tata \
       --passfile1 ../../var/pass/secret.tata \
       --host2 $HOST2 --user2 titi \
       --passfile2 ../../var/pass/secret.titi \
       --regextrans2 's/.*/INBOX.ALLIN/' \
       --folderrec 'INBOX.yop' --delete2 --usecache --nodelete2duplicates
}

ll_regextrans2_ALLIN_fake() 
{
       $CMD_PERL ./imapsync \
       --host1 $HOST1 --user1 tata \
       --passfile1 ../../var/pass/secret.tata \
       --host2 $HOST2 --user2 titi \
       --passfile2 ../../var/pass/secret.titi \
       --regextrans2 's/.*/INBOX.ALLIN/' \
       --foldersizes \
       --folderrec 'INBOX.yop' --delete2
}


ll_regextrans2_ALLIN_useuid() 
{
       $CMD_PERL ./imapsync \
       --host1 $HOST1 --user1 tata \
       --passfile1 ../../var/pass/secret.tata \
       --host2 $HOST2 --user2 titi \
       --passfile2 ../../var/pass/secret.titi \
       --foldersizes \
       --regextrans2 's/.*/INBOX.ALLIN/' \
       --folderrec 'INBOX.yop' --delete2 --useuid
}



ll_sep2() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --sep2 '\\' --dry
}

ll_bad_login()
{
    ! $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.toto \
        --host2 $HOST2 --user2 notiti \
        --passfile2 ../../var/pass/secret.titi
   
}

ll_authentication_failure_user1() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --password1 wrong \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi
         test "$?" = "$EXIT_AUTHENTICATION_FAILURE_USER1"
}
ll_authentication_failure_user2() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --password2 wrong
         test "$?" = "$EXIT_AUTHENTICATION_FAILURE_USER2"
}

ll_authentication_failure_user12() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --password1 wrong \
         --host2 $HOST2 --user2 titi \
         --password2 wrong
         test "$?" = "$EXIT_AUTHENTICATION_FAILURE_USER1"
}


ll_bad_host1()
{
    $CMD_PERL ./imapsync \
        --host1 badhostkaka --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi 
    test "$EXIT_CONNECTION_FAILURE_HOST1" = "$?"
   
}


ll_bad_host2()
{
    $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 badhostkiki --user2 titi \
        --passfile2 ../../var/pass/secret.titi 
    test "$EXIT_CONNECTION_FAILURE_HOST2" = "$?"
}

ll_bad_host12()
{
    $CMD_PERL ./imapsync \
        --host1 badhostkaka --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 badhostkiki --user2 titi \
        --passfile2 ../../var/pass/secret.titi 
    test "$EXIT_CONNECTION_FAILURE_HOST1" = "$?"
}



ll_bad_host_ssl()
{
    ! $CMD_PERL ./imapsync \
        --host1 badhost --user1 toto \
        --passfile1 ../../var/pass/secret.toto \
        --host2 badhost --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --ssl1 --ssl2 
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
                --dry --debug
                echo 'rm /home/vmail/titi/.yop.yap/cur/*'
}


ll_useheader_Received() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --useheader 'Received' \
                --dry --debug
                echo 'rm /home/vmail/titi/.yop.yap/cur/*'
}

ll_useheader_Message_ID_Received() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --useheader 'Received' --useheader 'Message-ID' \
                --dry --debug
                echo 'rm /home/vmail/titi/.yop.yap/cur/*'
}


ll_useheader_noheader() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --useheader 'NoExist' \
                --debug --delete2 --addheader
                echo 'rm /home/vmail/titi/.yop.yap/cur/*'
}



ll_skipmess() 
{
        if can_send; then
                #echo3 Here is plume
		sendtestmessage tata 
        fi
        sendtestmessage tata 
	$CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --nofoldersizes \
        --skipmess 'm{.*}ism' 
}

ll_skipmess_8bits() 
{
        if can_send; then
                #echo3 Here is plume
		SUBJ="`echo -e 'xFF:\0277'`"
		sendtestmessage tata "$SUBJ"
        fi
	#return
	$CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --nofoldersizes --noreleasecheck \
        --skipmess 'm/[\x80-\xff]/' 
}

ll_skipmess_Content_Type_Message_partial() 
{
	$CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.partial --nofoldersizes --noreleasecheck \
        --skipmess 'm{\A((?:[^\n]+\r\n)+|)^Content-Type: Message/Partial;[^\n]*\n(?:\r\n|.*\r\n\r\n)}ism'  --dry --addheader 
	echo "sudo rm -rf /home/vmail/titi/.partial/cur/*"

#        --skipmess 'm{\A((?:[^\n]+\n)+|)^Content-Type: Message/Partial;[^\n]*\n(?:\r?\n|.*\r?\n\r?\n)}ism'  --dry --addheader 
}

ll_skipmess_not_From() 
{
        sendtestmessage tata 
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --nofoldersizes \
        --skipmess 'm{\A(?!.*^From:[^\n]*tartanpion\@machin\.truc)}xms'
}


ll_regexmess() 
{
        if can_send; then
                rm -f /home/vmail/titi/.yop.yap/cur/*
        fi
        
        # \157 is octal for o
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --regexmess 's/\157/O/g' \
                --regexmess 's/p/Z/g' \
                --debug 
                
        if can_send; then
                file=`ls -t /home/vmail/titi/.yop.yap/cur/* | tail -1`
                diff ../../var/imapsync/tests/ll_regexmess/dest_01 $file
                echo 'sudo rm -fv /home/vmail/titi/.yop.yap/cur/*'
        fi
}

ll_regexmess_8bit_X()
{
        if can_send; then
                rm -f /home/vmail/titi/.oneemail/cur/*
        fi
        
        # All f should become X
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.oneemail \
                --regexmess 'tr [f] [\x99]' \
                --regexmess 'tr [\x80-\xff] [X]' \
                --debug 
}

ll_regexmess_add_CRLF_if_needed()
{
        if can_send; then
                rm -f /home/vmail/titi/.oneemail/cur/*
        fi
        
        # The first one is to be in the case of missing the last \r\n
        # it actually removes it. The second one is the fix.
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.oneemail \
                --regexmess "s{\r\n\z}{}gxms" \
                --regexmess "s{(?<![\n])\z}{\r\n}gxms" \
                --debug
}



ll_regexmess_bad_regex() 
{
        ! $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.yop.yap \
        --regexmess 'I am BAD' 
}

ll_regexmess_trailing_NUL() 
{
        if can_send; then 	
                rm -fv /home/vmail/titi/.NUL_char/cur/*
		echo /home/vmail/tata/.NUL_char/cur/*
	fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.NUL_char \
                --debugcontent \
                --regexmess 's/(\x00)+\Z//g' 
                
        if can_send; then 	
		file=`ls -t /home/vmail/titi/.NUL_char/cur/* | tail -1`
                diff ../../var/imapsync/tests/ll_regexmess/dest_02_null_removed $file
                #echo 'sudo rm -fv /home/vmail/titi/.NUL_char/cur/*'
	fi
}


ll_regexmess_add_header()
{
        if at_home; then
                rm -f /home/vmail/titi/.yop.yap/cur/*
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --regexmess 's/\A/X-migrated-from-foo: 20100617\n/' \
                --search 'SUBJECT add_some_header_please'  \
                --debugcontent 
                
        if at_home; then
                file=`ls -t /home/vmail/titi/.yop.yap/cur/* | tail -1`
                diff W/t/07_ll_regexmess_add_header.txt $file || return 1
                echo 'sudo rm -fv /home/vmail/titi/.yop.yap/cur/*'
        fi
}


ll_regexmess_add_header_path()
{
        if at_home; then
                rm -fv "/home/vmail/titi/.yop.blanc  blanc/cur/"*
        fi
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder "INBOX.yop.blanc  blanc" \
                --regexmess 's/\A/X-ImapSync-OriginalPath-$sync->{user1}: $sync->{ h1_current_folder }\n/' \
                --search 'SUBJECT add_some_header_please'  \
                --debugcontent 
                
        if at_home; then
                file=`ls -t "/home/vmail/titi/.yop.blanc  blanc/cur/"* | tail -1`
                diff W/t/08_ll_regexmess_add_header_path.txt "$file" || return 1
                echo 'sudo rm -fv "/home/vmail/titi/.yop.blanc  blanc/cur/"*'
        fi
        
}

ll_regexmess_add_header_path_verif()
{
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 titi \
                --passfile1 ../../var/pass/secret.titi \
                --host2 $HOST2 --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --folder "INBOX.yop.blanc  blanc" \
                --search1 'HEADER X-ImapSync-OriginalPath-tata ""'  \
                --debugcontent --dry --useuid --debugimap1

        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 titi \
                --passfile1 ../../var/pass/secret.titi \
                --host2 $HOST2 --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --folder "INBOX.yop.blanc  blanc" \
                --search1 'HEADER X-ImapSync-OriginalPath-tata "INBOX.yop.blanc  blanc"'  \
                --debugcontent --dry --useuid --debugimap1

}


ll_regexmess_change_header() 
{
# 
        if at_home; then
                rm -f /home/vmail/titi/.yop.yap/cur/*
        fi
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --regexmess 's{\A(.*?(?! ^$))^Date:\ \(Invalid\)(.*?)$}{$1Date: Thu, 1 Jun 2017 23:59:59 +0000}xms' \
				--search "HEADER Date Invalid"  \
                --debugcontent --dry
                
}

ll_regexmess_truncate_long_message_regex() 
{
# 
        if at_home; then
                rm -f /home/vmail/titi/.yop.yap/cur/*
        fi
        # Does not work 
                ! $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --regexmess 's/.{40000}\K.*//s'  \
                --debugcontent --minsize 100000
                # Quantifier in {,} bigger than 32766 in regex; marked by <-- HERE in m/.{ <-- HERE 40000}
                
}

ll_regexmess_truncate_long_message_substr() 
{
# 
        if at_home; then
                rm -f /home/vmail/titi/.yop.yap/cur/*
        fi
        # Works well
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --pipemess  'perl -0ne "print substr \$_,0,40000" '  \
                --debugcontent --minsize 100000
                
}


ll_regexmess_truncate_long_message_truncmess() 
{
# 
        if at_home; then
                rm -f /home/vmail/titi/.yop.yap/cur/*
        fi
        # Works well
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --truncmess 40000 \
                --debugcontent --minsize 100000
                
}




ll_search_not_header() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
				--search "NOT HEADER Date Invalid" --debugcontent --dry
}

ll_regexmess_remove_header_Disposition() 
{
#Disposition-Notification-To: Gilles LAMIRAL <gilles@lamiral.info>
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.regexmess \
		--nofoldersizes \
                --regexmess 's{\A(.*?(?! ^$))(^Disposition-Notification-To:.*?\n)}{$1}gxms' \
                --debugcontent  --debug 
                echo "sudo sh -c 'rm /home/vmail/titi/.regexmess/cur/*'"
}

ll_disarmreadreceipts() 
{
#Disposition-Notification-To: Gilles LAMIRAL <gilles@lamiral.info>
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.disarm \
		--nofoldersizes \
                --disarmreadreceipts \
                --debugcontent  --debug --dry
                echo "sudo sh -c 'rm /home/vmail/titi/.disarm/cur/*'"
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
                --debug  
                echo 'rm /home/vmail/titi/.scwchu/cur/*'
}

ll_regexmess_wong() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.scwchu \
                --regexmess 's{\A}{Content-Type: text/plain; charset="big5"\n}gxms' \
                --debugcontent  --debug
                echo "sudo sh -c 'rm /home/vmail/titi/.scwchu/cur/*'"
}

ll_regexmess_wong_2() 
{
#Received: from hkuhp22.hku.hk
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.scwchu \
                --regexmess 's{\A(.*?(?!^$))^(Received: from hkuhp22.hku.hk.*?)$}{$1Content-Type: text/plain; charset="big5"\n$2}gms' \
                --debugcontent  --debug --dry
                echo "sudo sh -c 'rm /home/vmail/titi/.scwchu/cur/*'"
}

ll_flags() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --debugflags
                
                echo 'rm /home/vmail/titi/.yop.yap/cur/*'
}

ll_resyncflags() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --debugflags --resyncflags | grep 'Host1: flags init msg' || return 1
                
                echo 'rm /home/vmail/titi/.yop.yap/cur/*'
}

ll_syncflagsaftercopy() 
{
# courier doesn't gives the flags just after an copy
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap --nofoldersizes \
                --debugflags --syncflagsaftercopy # | grep 'replacing h2 flags' || return 1
                                                  # | grep 'could not get its flags' || return 1
                echo 'sudo rm /home/vmail/titi/.yop.yap/cur/*'
}



ll_noresyncflags() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --debugflags --noresyncflags | grep 'Host1: flags init msg' && return 1
                
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
                --regexflag 's/\\Answered/\$Forwarded/g' --debugflags
                
                echo 'rm -f /home/vmail/titi/.yop.yap/cur/*'
}

ll_regex_flag_remove() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --regexflag 's/\\Indexed//gi' --debugflags
                
                echo 'rm -f /home/vmail/titi/.yop.yap/cur/*'
}

ll_regex_flag_bad() 
{
                ! $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --regexflag 'I am bad' --debugflags
                
                echo 'sudo rm -fv /home/vmail/titi/.yop.yap/cur/*'
}




ll_regex_flag2() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --debug --regexflag s/\\\\Answered/\\\\Flagged/g 
                
                echo 'sudo rm -fv /home/vmail/titi/.yop.yap/cur/*'
}


ll_regex_flag3() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --debug --regexflag s/\\\\Answered//g 
                
                echo 'rm -f /home/vmail/titi/.yop.yap/cur/*'
}

ll_regex_flag4() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap --nofoldersizes \
                --regexflag 's/\$label1/\\label1/g' \
                --regexflag "s/\\\$Forwarded//g" --debugflags
                
                echo 'sudo rm -f /home/vmail/titi/.yop.yap/cur/*'
}

ll_regex_flag5() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --debugflags --regexflag "s/Answered/Flagged/g"
                
                echo 'rm -f /home/vmail/titi/.yop.yap/cur/*'
}




ll_regex_flag6_add_SEEN() 
{
	$CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 tata \
        --passfile2 ../../var/pass/secret.tata \
        --folder INBOX.flagsetSeen \
        --debugflags --regexflag "s/(.*)/\$1 \\\\Seen/" --dry 

        echo 'rm -f /home/vmail/titi/.yop.yap/cur/*'
}

ll_regex_flag7_add_SEEN() 
{
	$CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.yop.yap \
        --debugflags --regexflag 's,,\\Seen ,' --dry 
# on windows         --regexflag "s,,\\Seen ," --dry 

        echo 'rm -f /home/vmail/titi/.yop.yap/cur/*'
}

ll_regex_flag8_add_SEEN_if_not_here() 
{
	$CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.flagsetSeen --nofoldersizes \
        --debugflags --dry --regexflag 's,\\Seen,,' --regexflag 's,,\\Seen ,'
             # On windows: --regexflag "s,((?!\\Seen).*),$1 \\Seen,"
}

ll_regex_flag8_add_SEEN_always() 
{
	$CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.flagsetSeen --nofoldersizes \
        --debugflags --dry --regexflag "s,,\\\\Seen ,"

}


ll_regex_flag_keep_only() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --debug \
                --regexflag 's/(.*)/$1 jrdH8u/' \
                --regexflag 's/.*?(\\Seen|\\Answered|\\Flagged|\\Deleted|\\Draft|jrdH8u)/$1 /g' \
                --regexflag 's/(\\Seen|\\Answered|\\Flagged|\\Deleted|\\Draft|jrdH8u) (?!(\\Seen|\\Answered|\\Flagged|\\Deleted|\\Draft|jrdH8u)).*/$1 /g' \
                --regexflag 's/jrdH8u *//'
                
                echo 'rm -f /home/vmail/titi/.yop.yap/cur/*'
}

ll_regex_flag_keep_only_phil() 
{
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.yop.yap \
                --debugflags \
                --regexflag 's/(.*)/$1 jrdH8u/' \
                --regexflag 's/.*?(?:(\\(?:Answered|Flagged|Deleted|Seen|Draft)\s?)|$)/defined($1)?$1:q()/eg' \
                --regexflag 's/jrdH8u *//'
                
                echo 'rm -f /home/vmail/titi/.yop.yap/cur/*'
}




ll_tls_justconnect() {
 $CMD_PERL ./imapsync \
  --host1 $HOST1 \
  --host2 $HOST2 \
  --tls1 --tls2 \
  --justconnect  --debugimap
}

ll_tls_justconnect_SSL_version() {
 $CMD_PERL ./imapsync \
  --host1 $HOST1 \
  --host2 $HOST2 \
  --tls1 --tls2 \
  --justconnect  --debugimap --ssl1_SSL_version SSLv3 --ssl2_SSL_version SSLv2
}




ll_tls_justlogin() {
 $CMD_PERL ./imapsync \
  --host1 $HOST1 --user1 tata \
  --passfile1 ../../var/pass/secret.tata \
  --host2 $HOST2 --user2 titi \
  --passfile2 ../../var/pass/secret.titi \
  --tls1 --tls2 \
  --justlogin --debugimap
}


ll_tls_devel() {
   ll_justlogin && ll_ssl_justlogin \
&& ll_tls_justconnect && ll_tls_justlogin
}

ll_tls() {
 $CMD_PERL ./imapsync \
  --host1 $HOST1 --user1 tata \
  --passfile1 ../../var/pass/secret.tata \
  --host2 $HOST2 --user2 titi \
  --passfile2 ../../var/pass/secret.titi \
  --tls1 --tls2 
}


ll_ssl_justconnect() {
                $CMD_PERL ./imapsync \
		--host1 $HOST1 \
                --host2 $HOST2 \
                --ssl1 --ssl2 \
                --justconnect
}

ll_ssl_justconnect_SSL_version() {
                $CMD_PERL ./imapsync \
		--host1 $HOST1 \
                --host2 $HOST2 \
                --ssl1 --ssl2 \
                --justconnect --ssl1_SSL_version SSLv3 --ssl2_SSL_version SSLv2
}


ll_ssl_justconnect_sslargs() {
                $CMD_PERL ./imapsync \
		--host1 $HOST1 \
                --host2 $HOST2 \
                --ssl1 --ssl2 \
                --justconnect --sslargs1 SSL_version=SSLv23 --sslargs1 SSL_verify_mode=0
}

ll_ssl_justconnect_sslargs_SSL_verify_mode1() {
                $CMD_PERL ./imapsync \
		--host1 $HOST1 \
                --host2 $HOST2 \
                --ssl1 --ssl2 \
                --justconnect --sslargs1 SSL_version=SSLv23 --sslargs1 SSL_verify_mode=1
}

ll_ssl_justconnect_sslargs_SSL_versionTLSv1_1() {
                $CMD_PERL ./imapsync \
		--host1 $HOST1 \
                --host2 $HOST2 \
                --tls1 \
                --justconnect --sslargs1 SSL_version=TLSv1_1 --sslargs1 SSL_verify_mode=0 --debugssl 4
}






ll_ssl1_tls2_justconnect() {
        $CMD_PERL ./imapsync \
	 --host1 $HOST1 \
         --host2 $HOST2 \
         --ssl1 --tls2  \
         --justconnect --debugimap
}

ll_tls1_ssl2_justconnect() {
        $CMD_PERL ./imapsync \
	 --host1 $HOST1 \
         --host2 $HOST2 \
         --tls1 --ssl2 \
         --justconnect --debugimap
}

ll_ssl1_tls1_justconnect() {
        $CMD_PERL ./imapsync \
	 --host1 $HOST1 \
         --host2 $HOST2 \
         --ssl1 --tls1   \
         --justconnect --debugimap
}

ll_ssl_justconnect_SSL_VERIFY_PEER() {
                $CMD_PERL ./imapsync \
		--host1 $HOST1 \
                --ssl1 \
                --justconnect \
                --host2 imap.gmail.com \
                --ssl2 \
                --sslargs2 SSL_verify_mode=1 
#--sslargs2 SSL_ca_file=/etc/ssl/certs/ca-certificates.crt 
}


ll_justconnect_devel() {
   ll_justconnect && ll_tls_justconnect && ll_ssl_justconnect && ll_ssl1_tls2_justconnect && ll_tls1_ssl2_justconnect && ! ll_ssl1_tls1_justconnect
}



ll_ssl_justlogin() {
        $CMD_PERL ./imapsync \
	 --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --ssl1 --ssl2 \
         --justlogin
}

ll_ssl_justlogin_SSL_version() {
        $CMD_PERL ./imapsync \
	 --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --ssl1 --ssl2 \
         --justlogin --ssl1_SSL_version SSLv23 --ssl2_SSL_version SSLv23 --debugssl 4
}

ll_ssl_justlogin_sslargs() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --ssl1 --ssl2 \
        --sslargs1 SSL_version=SSLv3 --sslargs1 SSL_verify_mode=1
}



ll_tls_justlogin_sslargs_failure_EXIT_TLS_FAILURE() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --tls1 --tls2 \
        --sslargs1 SSL_version=SSLv2 
        test "$?" = "$EXIT_TLS_FAILURE"
}




ll_ssl_tls_justlogin() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --ssl1 --tls1  --ssl2 --tls2  \
         --justlogin --debug
         test "$?" = "$EXIT_TLS_FAILURE"
}

ll_justlogin_devel() {
    ll_justlogin && ll_ssl_justlogin && ll_tls_justlogin && ll_ssl_tls_justlogin 
}

ll_ssl() {
        if can_send; then
                #echo3 Here is plume
		sendtestmessage
        fi
        $CMD_PERL ./imapsync \
	 --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --ssl1 --ssl2 
}

ll_authmech_PLAIN() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --nofoldersizes \
                --authmech1 PLAIN --authmech2 PLAIN 
}

ll_authmech_PLAIN_ssl() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --ssl1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --ssl2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --nofoldersizes \
                --authmech1 PLAIN --authmech2 PLAIN 
}



ll_authmech_XOAUTH2_gmail() {
                ! ping -c1 imap.gmail.com || { $CMD_PERL ./imapsync \
                --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.xoauth2 \
                --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.xoauth2 \
                --justlogin \
                --authmech1 XOAUTH2 --authmech2 XOAUTH2 --debug | grep unauthorized_client ; } 
}
ll_authmech_xoauth2_gmail() { ll_authmech_XOAUTH2_gmail; }

ll_authmech_XOAUTH2_json_gmail() {
                ! ping -c1 imap.gmail.com || { $CMD_PERL ./imapsync \
                --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com \
                --password1 ../../var/pass/secret.xoauth2.json \
                --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com \
                --password2 ../../var/pass/secret.xoauth2.json \
                --justlogin \
                --authmech1 XOAUTH2 --authmech2 XOAUTH2 --debug | grep unauthorized_client ; } 
}
ll_authmech_xoauth2_json_gmail() { ll_authmech_XOAUTH2_json_gmail; }

ll_authmech_XOAUTH2_json_gmail_app() {
                ! ping -c1 imap.gmail.com || { $CMD_PERL ./imapsync \
                --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com \
                --password1 ../../var/pass/secret.xoauth2.json \
                --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com \
                --password2 ../../var/pass/secret.xoauth2.json \
                --justlogin \
                --authmech1 XOAUTH2 --authmech2 XOAUTH2 --debugimap ; } 
}
ll_authmech_xoauth2_json_gmail_app() { ll_authmech_XOAUTH2_json_gmail_app; }



ll_authmech_XOAUTH2_gmail_proxy() {
                ! ping -c1 imap.gmail.com || https_proxy=http://localhost:8080/ $CMD_PERL ./imapsync \
                --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.xoauth2 \
                --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.xoauth2 \
                --justlogin \
                --authmech1 XOAUTH2 --authmech2 XOAUTH2 --debug
}
ll_authmech_xoauth2_gmail_proxy() { ll_authmech_XOAUTH2_gmail_proxy; }


ll_authmech_NTLM() {
                # It fails since I don't have NTLM available
                ! $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin \
                --debugimap1 --authmech1 NTLM --notrylogin
}

ll_authmech_NTLM_domain() {
                # It fails since I don't have NTLM available
                ! $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin \
                --authmech1 NTLM --domain1 freshgrillfoods.com --debugimap1 --notrylogin
}

ll_authmech_NTLM_trylogin_ok() {
                # It succeeds because --trylogin is set by default (for now).
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --authmech1 NTLM --trylogin --justlogin
}

ll_authmech_NTLM_trylogin_fail() {
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --password2 'cacakiki' \
                --authmech2 NTLM --trylogin --justlogin
                test "$?" = "$EXIT_AUTHENTICATION_FAILURE_USER2"
}




ll_authmech_X_MASTERAUTH()
{
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --authmech1 'X-MASTERAUTH' # --debugimap1
}

ll_authuser()
{
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --authuser2 titi --debugimap2
}

ll_proxyauth_missing_authuser()
{
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 anything \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --proxyauth2
                test "$?" = "$EX_USAGE"
}



ll_proxyauth_authuser()
{
        $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 anything \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --proxyauth2 --authuser2 titi --debugimap2
                test "$?" = "$EXIT_AUTHENTICATION_FAILURE_USER2"
}






ll_authmech_LOGIN() {

                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --nofoldersizes \
                --authmech1 LOGIN --authmech2 LOGIN 
}

ll_authmech_CRAMMD5() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfoldersizes --nofoldersizes \
                --authmech1 CRAM-MD5 --authmech2 CRAM-MD5
}

ll_delete1() {

        # The initial state is a same message on both sides
        ls -ld /home/vmail/tata/.oneemail3/cur/* || return 1
        ls -ld /home/vmail/titi/.oneemail3/cur/* || return 1
        echo 11111111111111111111111 tata titi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.oneemail3 --delete1 --debugimap

        #find /home/vmail/titi/.oneemail3/ || :
        echo After first sync, tata has none, titi has one message
        ! test -f /home/vmail/tata/.oneemail3/cur/* || return 1
        test -f /home/vmail/titi/.oneemail3/cur/*   || return 1

        echo 222222222222222222222222 back: titi tata
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 titi \
        --passfile1 ../../var/pass/secret.titi \
        --host2 $HOST2 --user2 tata \
        --passfile2 ../../var/pass/secret.tata \
        --folder INBOX.oneemail3 --delete1 --delete2duplicates
        
        echo After second sync reverse, tata has one, titi has no message
        test -f /home/vmail/tata/.oneemail3/cur/*   || return 1
        ! test -f /home/vmail/titi/.oneemail3/cur/* || return 1
        
        echo 3333333333333333333333333 initial state
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.oneemail3

        #find /home/vmail/titi/.oneemail3/ || :
        echo ll_delete1 finished
}

ll_delete1_twoemails()
{
        # initial 
        ls /home/vmail/tata/.twoemails/cur/* || return 1

	echo 11111111111111111111111 tata titi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.twoemails --delete1

	#find /home/vmail/titi/.twoemails/ || :
	echo After first sync, tata has none, titi has two messages
        ! ls  /home/vmail/tata/.twoemails/cur/* || return 1
	ls /home/vmail/titi/.twoemails/cur/*    || return 1

	echo 222222222222222222222222 back: titi tata
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 titi \
        --passfile1 ../../var/pass/secret.titi \
        --host2 $HOST2 --user2 tata \
        --passfile2 ../../var/pass/secret.tata \
        --folder INBOX.twoemails --delete1
        
        ls   /home/vmail/tata/.twoemails/cur/* || return 1
        ! ls /home/vmail/titi/.twoemails/cur/* || return 1
        
	echo 3333333333333333333333333 initial state
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.twoemails

	#find /home/vmail/titi/.twoemails/ || :
	echo ll_delete1_twoemails finished
}

ll_delete1_twoemails_dry()
{
        # initial 
        ls /home/vmail/tata/.twoemails/cur/* || return 1

        echo 11111111111111111111111 tata titi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.twoemails --delete1 --dry --debug
}

ll_delete1_delete2() {
        ! $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 titi \
        --passfile1 ../../var/pass/secret.titi \
        --host2 $HOST2 --user2 tata \
        --passfile2 ../../var/pass/secret.tata \
        --delete1 --delete2
}


ll_delete2() {
        can_send && sendtestmessage titi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX \
        --delete2
}

ll_delete2_reverse() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 titi \
        --passfile1 ../../var/pass/secret.titi \
        --host2 $HOST2 --user2 tata \
        --passfile2 ../../var/pass/secret.tata \
        --folder INBOX \
        --delete2  
}



ll_delete1_reverse() {
        ll_INBOX
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 titi \
        --passfile1 ../../var/pass/secret.titi \
        --host2 $HOST2 --user2 tata \
        --passfile2 ../../var/pass/secret.tata \
        --folder INBOX \
        --delete1 --minage 10 --maxage 999 # --dry

}

ll_delete1_reverse_useuid() {
        ll_INBOX
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 titi \
        --passfile1 ../../var/pass/secret.titi \
        --host2 $HOST2 --user2 tata \
        --passfile2 ../../var/pass/secret.tata \
        --folder INBOX \
        --delete1 --minage 100 --maxage 600 \
	--useuid
}


ll_delself() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 toto \
        --passfile1 ../../var/pass/secret.toto \
        --host2 $HOST2 --user2 delme \
        --passfile2 ../../var/pass/secret.delme 

        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 delme \
        --passfile1 ../../var/pass/secret.delme \
        --host2 $HOST2 --user2 delme \
        --passfile2 ../../var/pass/secret.delme \
        --delete1 --noexpungeaftereach

        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 delme \
        --passfile1 ../../var/pass/secret.delme \
        --host2 $HOST2 --user2 delme \
        --passfile2 ../../var/pass/secret.delme \
        --justfolders --delete2folders --regextrans2 "s/.*/INBOX/" --foldersizes

        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 delme \
        --passfile1 ../../var/pass/secret.delme \
        --host2 $HOST2 --user2 delme \
        --passfile2 ../../var/pass/secret.delme \
        --justfoldersizes

}



ll_delete2_minage() {
        can_send && sendtestmessage titi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX \
        --delete2  --minage 1
}

ll_delete2_minage_useuid() {
        can_send && sendtestmessage titi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX \
        --delete2 --uidexpunge2 --minage 1 --useuid
}

ll_delete2_uidexpunge2_implicit() {
        can_send && sendtestmessage titi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX \
        --delete2 --useuid
}

ll_delete1duplicates() {
        can_send && sendtestmessage titi thailah9eem4iHei
        can_send && sendtestmessage tata thailah9eem4iHei
        can_send && sendtestmessage tata thailah9eem4iHei
        can_send && sendtestmessage tata thailah9eem4iHei
        can_send && sendtestmessage tata thailah9eem4iHei
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX  --maxage 1 --useheader Subject # --delete2duplicates
}




ll_delete2duplicates() {
        #can_send && sendtestmessage titi "test ll_delete2duplicates"
        #can_send && sendtestmessage tata "test ll_delete2duplicates"
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX   \
        --delete2duplicates --uidexpunge2 --useheader Subject --dry 
}




ll_duplicates_across_folders() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.zz_1   \
        --folder INBOX.zz_2 \
        --folder INBOX.zz_3 \
        --skipcrossduplicates --debugcrossduplicates 
}



ll_delete2_dev() {
        can_send && sendtestmessage titi
        can_send && sendtestmessage
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --include zz --include ZZ  --regextrans2 's,.*,INBOX.z_merge,' \
        --delete2
}


ll_maxmessagespersecond() {
        ll_delete1_reverse
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX \
        --maxmessagespersecond 3.3
}

ll_maxbytespersecond() {
        ll_delete1_reverse
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX \
        --maxbytespersecond 2000 --nofoldersizes
}

ll_maxbytespersecond_0() {
        ll_delete1_reverse
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX \
        --maxbytespersecond 1 --nofoldersizes --maxsleep 0
}



ll_maxbytesafter() {
        ll_delete1_reverse
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX \
        --maxbytespersecond 1000 --maxbytesafter 20000 --nofoldersizes
}


big2_bigmail_clean()
{
        echo 'sudo sh -c "rm -v /home/vmail/big2/.bigmail/cur/*"'
        sudo sh -c "rm -v /home/vmail/big2/.bigmail/cur/*"
}

ll_bigmail() {
        time -p $CMD_PERL ./imapsync \
        --host1 $HOST1  --user1 big1 \
        --passfile1 ../../var/pass/secret.big1 \
        --host2 $HOST2 --user2 big2 \
        --passfile2 ../../var/pass/secret.big2 \
        --folder INBOX.bigmail  --debugmemory --nofoldersizes 
        echo 'sudo sh -c "rm -v /home/vmail/big2/.bigmail/cur/*"'
}

ll_bigmail_fastio() {
        time -p $CMD_PERL ./imapsync \
        --host1 $HOST1  --user1 big1 \
        --passfile1 ../../var/pass/secret.big1 \
        --host2 $HOST2 --user2 big2 \
        --passfile2 ../../var/pass/secret.big2 \
        --folder INBOX.bigmail --debugmemory --nofoldersizes --fastio1 --fastio2
        echo 'sudo sh -c "rm -v /home/vmail/big2/.bigmail/cur/*"'
}


ll_bigmail_fastio_profile()
{
        test "0" = "`id -u`" || {
                echo Do instead
                echo "sudo sh tests.sh ll_bigmail_fastio_profile"
                return
        }
        
        big2_bigmail_clean
        sync 
        echo 3 >/proc/sys/vm/drop_caches
        free
        ll_bigmail_fastio
        echo End of ll_bigmail_fastio

        big2_bigmail_clean
        sync
        echo 3 >/proc/sys/vm/drop_caches
        free
        ll_bigmail
        echo End of ll_bigmail
        free
}



# In mandatory_tests
memory_stress() {
        free
        $CMD_PERL ./imapsync --testsunit tests_memory_stress && free
}

ll_memory_consumption() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1  --user1 big1 \
        --passfile1 ../../var/pass/secret.big1 \
        --host2 $HOST2 --user2 big2 \
        --passfile2 ../../var/pass/secret.big2 \
        --folder INBOX.bigmail2 \
	--nofoldersizes
        echo 'sudo sh -c "rm -v /home/vmail/big2/.bigmail2/cur/*"'
}


ll_syncduplicates() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST1 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.duplicates --debug --syncduplicates # --dry
}

ll_syncduplicates_delete2() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST1 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.duplicates --syncduplicates --delete2 # --dry
}

ll_syncduplicates_delete2_delete2duplicates() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST1 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.duplicates --syncduplicates --delete2 --delete2duplicates # --dry
}



ll_syncduplicates_noskipsize() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST1 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.duplicates --debug --syncduplicates --noskipsize # --dry
}

ll_syncduplicates_usecache() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST1 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.duplicates --debug --syncduplicates --usecache #--dry
}

ll_syncduplicates_reverse() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 titi \
                --passfile1 ../../var/pass/secret.titi \
                --host2 $HOST1 --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --folder INBOX.duplicates --debug --syncduplicates # --dry
}


ll_remove_duplicates() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST1 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX.duplicates --delete2duplicates # --dry
}





msw() {
	if can_send; then
        	sendtestmessage toto
	fi
        scp imapsync test.bat test_exe.bat\
            ../../var/pass/secret.toto \
            ../../var/pass/secret.titi \
            ../../var/pass/secret.tata \
            Admin@c:'C:/msys/1.0/home/Admin/imapsync/'

        ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test.bat'
	scp Admin@c:'C:/msys/1.0/home/Admin/imapsync/imapsync.exe' .
}

msw2() {
	if can_send; then
        	sendtestmessage toto
	fi
        scp imapsync test_exe.bat\
            ../../var/pass/secret.toto \
            ../../var/pass/secret.titi \
            ../../var/pass/secret.tata \
            Admin@c:'C:/msys/1.0/home/Admin/imapsync/'

        ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'
}

ll_change_characters_doublequotes() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justfolders --dry --nofoldersizes \
                --regextrans2 's,\",_,g' 

}



ll_change_characters_gmail() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder "INBOX. f g\h\"i'j " --justfolders \
                --regextrans2 "s/['\"\\\\]/_/g" --regextrans2 's,(/|^) +,$1,g' --regextrans2 's, +(/|$),$1,g'

}

ll_blanc_vs_hyphen_gmail() {
                $CMD_PERL ./imapsync \
                --host1 $HOST1  --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder "INBOX.A-B" --folder "INBOX.A B" --folder "INBOX.A.B" --justfolders
}


# Gmail tests
# A big mess!

xxxxx_gmail() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--nofoldersizes \
		--regextrans2 's,(/|^) +,$1,g' --regextrans2 's, +(/|$),$1,g' \
		--exclude 'INBOX.yop.YAP' \
		--regextrans2 "s,^Messages envoy&AOk-s$,[Gmail]/Messages envoy&AOk-s," \
		--regextrans2 "s,^Sent$,[Gmail]/Sent Mail," \
		--folder 'INBOX.Messages envoy&AOk-s' \
		--folder 'INBOX.Sent' 

}

xxxxx_gmail_useuid() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--nofoldersizes \
		--regextrans2 "s,^Sent$,[Gmail]/Sent Mail," \
		--folder 'INBOX.Sent' --useuid --dry
}

xxxxx_gmail_02() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--nofoldersizes \
                --regextrans2 's,(.*),SMS,'
}

xxxxx_gmail_03() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--nofoldersizes \
                --folder INBOX.few_emails  --debug --useheader Message-ID --delete2 --dry
}

xxxxx_gmail_03_Received() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--nofoldersizes \
                --folder INBOX.few_emails  --debug --useheader Received --delete2 --dry
}


xxxxx_gmail_04_Sent() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
                --folder INBOX.Sent  \
                --regextrans2 's{Sent}{[Gmail]/Messages envoy&AOk-s}' \
		--debugflags 
}

xxxxx_gmail_05_justfolders() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--justfolders --nofoldersizes \
                --regextrans2 's,(/|^) +,$1,g' --regextrans2 's, +(/|$),$1,g' \
		--regextrans2 "s/[\^]/_/g" --debug
}


xxxxx_gmail_05_justlogin() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--justlogin
}

xxxxx_gmail_05_justlogin_exe() {

                ! ping -c1 imap.gmail.com || ./imapsync_elf_x86.bin \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--justlogin
}

xxxxx_gmail_05_justlogin_SSLv3() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--justlogin --ssl2_SSL_version SSLv3 --justconnect
}

xxxxx_gmail_05_justlogin_SSLv2() {

                ! ping -c1 imap.gmail.com || ! $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--justlogin --ssl2_SSL_version SSLv2
}

xxxxx_gmail_05_justlogin_SSLv23() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--justlogin --ssl2_SSL_version SSLv23
}




xxxxx_gmail_trailing_blanks() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
                --nofoldersizes \
                --justfolders \
                --include "[ ]" \
                --regextrans2 's,^ +| +$,,g' --regextrans2 's,/ +| +/,/,g'
}

xxxxx_gmail_trailing_blanks_gmail2() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
                --nofoldersizes \
                --justfolders \
                --include "[ ]" \
                --gmail2 --dry
}

xxxxx_gmail_delete2folders() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
                --nofoldersizes \
                --justfolders \
                --include "[ ]" \
                --gmail2 --delete2foldersonly "m, ," --delete2foldersbutnot 'm,Gmail,' 
}


xxxxx_gmail_07_hierarchy() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--nofoldersizes \
                --folder INBOX.yop.yup.yip.yap.yep --justfolders
}


xxxxx_gmail_07_subfolder() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--nofoldersizes \
                --justfolders --subfolder2 BBB
}




xxxxx_gmail_09_via_stunnel() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 $HOST2 \
                --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 localhost \
                --port2 9993 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
		--foldersizes \
                --folder INBOX 
}



gmail_xxxxx() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 $HOST2 \
                --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
		--nofoldersizes \
                --dry --justfolders --exclude "\[Gmail\]/All Mail"
}


gmail() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 $HOST2 \
                --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --exclude Gmail --exclude "blanc\ $"
}

gmail_l_tata() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 $HOST2 \
                --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --folder INBOX 
}


gmail_justfolders() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 $HOST2 \
                --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
		--justfolders --exclude Gmail --exclude "blanc\ $"
}

gmail_justfolders_remove_Gmail() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 $HOST2 \
                --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
		--regextrans2 "s,\[Gmail\].,," --dry --justfolders
}




gmail_via_stunnel_ks() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 ks.lamiral.info \
                --port1 243 --nossl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 $HOST2 \
                --user2 tata \
                --passfile2 ../../var/pass/secret.tata \
                --useheader 'Message-Id' \
                --useheader="X-Gmail-Received" \
                --debug --justfolders
}

easygmail_gmail1_gmail2() {
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
		--gmail1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --gmail2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justfolders
}

easygmail_gmail2()
{
                $CMD_PERL ./imapsync \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
		--host1 imap.gmail.com \
                --gmail2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justfolders
}


gmail_gl0_justlogin()
{
        $CMD_PERL ./imapsync \
                --gmail1 --user1 imapsync.gl0@gmail.com --passfile1 ../../var/pass/secret.imapsync.gl0_gmail \
                --gmail2 --user2 imapsync.gl0@gmail.com --passfile2 ../../var/pass/secret.imapsync.gl0_gmail \
                --justlogin
}

gmail_gl0_justlogin_oauthdirect()
{
        cd /home/gilles/public_html/imapsync/W/learn
        pwd
        . ./oauth2.memo
        regenerate_access_token
        access_token=`cat oauth2_access_token.txt`
        echo "$access_token"
        
        generate_oauth2_string_for_imap_from_access_token "$access_token"
        oauth2_string=`cat oauth2_string_for_oauthdirect.txt`
        echo oauth2_string="$oauth2_string"
        cd -
        pwd
        echo "2oauth2_string=$oauth2_string"
        $CMD_PERL ./imapsync \
                --gmail1 --user1 imapsync.gl0@gmail.com --passfile1 ../../var/pass/secret.imapsync.gl0_gmail \
                --gmail2 --user2 imapsync.gl0@gmail.com --passfile2 ../../var/pass/secret.imapsync.gl0_gmail \
                --justlogin --oauthdirect1 "$oauth2_string" --oauthdirect2 "$oauth2_string" --debugimap --showpasswords
        pwd
}

gmail_gl0_oauthdirect_failure_login_success()
{

        oauth2_string="kaka"
        echo "2oauth2_string=$oauth2_string"
        $CMD_PERL ./imapsync \
                --gmail1 --user1 imapsync.gl0@gmail.com --passfile1 ../../var/pass/secret.imapsync.gl0_gmail \
                --gmail2 --user2 imapsync.gl0@gmail.com --passfile2 ../../var/pass/secret.imapsync.gl0_gmail \
                --justlogin --oauthdirect1 "$oauth2_string" --oauthdirect2 "$oauth2_string" --debugimap --showpasswords

}


all_login_tests()
{
        run_tests ll_authmech_PREAUTH \
        ll_authmd5 \
        ll_authmd51 \
        ll_authmd52 \
        ll_noauthmd5 \
        gmail_gl0_justlogin \
        gmail_gl0_justlogin_oauthdirect \
        ll_ssl_justlogin \
        ll_tls_justlogin \
        ll_tls_justlogin_sslargs_failure_EXIT_TLS_FAILURE \
        yahoo_xxxx_login \
        yahoo_xxxx_login_tls  \
        yahoo_xxxx_login_tls \
        ll_justlogin \
        ll_justlogin_notls \
        l_office365_SSL_verify_mode \
        office365_justlogin_ssl1_ssl2 \
        office365_justlogin_tls \
        office365_justlogin_tls2_office365 \
        office365_justlogin_ssl2_tls2_office365 \
        ll_ask_password \
        ll_env_password \
        
}


gmail_glX_all_justlogin()
{
error_list=""
for X in "" 0 1 2 3; do
        $CMD_PERL ./imapsync \
                --gmail1 --user1 imapsync.gl${X}@gmail.com --passfile1 ../../var/pass/secret.imapsync.gl${X}_gmail \
                --gmail2 --user2 imapsync.gl${X}@gmail.com --passfile2 ../../var/pass/secret.imapsync.gl${X}_gmail \
                --justlogin || { error_list="${error_list}[imapsync.gl${X}@gmail.com] " ; }
done
echo3 "error_list=$error_list"
test "X$error_list" = X;
}


gmail_glX_all_justfolderlist()
{
error_list=""
for X in "" 0 1 2 3; do
        $CMD_PERL ./imapsync \
                --gmail1 --user1 imapsync.gl${X}@gmail.com --passfile1 ../../var/pass/secret.imapsync.gl${X}_gmail \
                --gmail2 --user2 imapsync.gl${X}@gmail.com --passfile2 ../../var/pass/secret.imapsync.gl${X}_gmail \
                --no-modulesversion --justfolderlists --nocheckfoldersexist || { error_list="${error_list}[imapsync.gl${X}@gmail.com] " ; }
done
echo3 "error_list=$error_list"
test "X$error_list" = X;
}


gmail_gmail_slash_in_foldername()
{
        ./imapsync --gmail1 --user1 imapsync.gl1@gmail.com --passfile1 ../../var/pass/secret.imapsync.gl1_gmail \
                   --gmail2 --user2 imapsync.gl2@gmail.com --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                   --no-modulesversion  --dry --justfolders
}

gmail_gmail()
{
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justfolders --exclude Gmail  --exclude "blanc\ $" 
}

gmail_gmail_exclude()
{
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justfolders --exclude "/Trash" 
}




gmail_gmail_inet4() {
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justlogin --inet4
}



gmail_gmail_ipv6() {

                ! ping6 -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 2a00:1450:400c:c0a::6c \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 wl-in-x6c.1e100.net. \
                --ssl2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justlogin
}



gmail_gmail_automap() {
                $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justfolders --dry --automap --justautomap --f1f2 Junk=Junk --f1f2 Trash=Cake
}

gmail_gmail_noautomap() {

                $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justfolders --dry --noautomap 
}


gmail_gmail_justconnect() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justconnect --timeout 1
}

gmail_gmail_justlogin() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --justlogin --id --debugimap
}


gmail_gl_gl2_justfolders() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --justfolders --exclude Gmail  --exclude "blanc\ $" --dry
}


gmail_gl_gl2() {

                $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --folder INBOX --dry
}


gmail_gl_gl2_SUB() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 imapsync.gl@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --justfolders --nofoldersizes --exclude Gmail --regextrans2 "s,(.*),SUB/\$1,"
}

gmail_gl2_gl2_selectable()
{

        $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl2@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl2_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --dry --justautomap
}



gmail_gl_gl2_create_folder_old() { 

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --gmail1 \
                --user1 imapsync.gl@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl_gmail \
                --gmail2 \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --justfolders --exclude Gmail  --exclude "blanc\ $" \
                --create_folder_old --dry --nofoldersizes
}


gmail_gmail_search_NOT_HEADER_attachment()
{
        $CMD_PERL ./imapsync \
                --gmail1 \
                --user1 imapsync.gl@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl_gmail \
                --gmail2 \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
        --search "NOT HEADER Content-Disposition attachment" \
        --folder INBOX --dry 

        # Also works
        # --search 'HEADER Content-Type multipart/mixed' \

        # Does not work the OR
        # --search 'OR HEADER "Content-Disposition attachment" HEADER "Content-Type multipart/mixed"' \
}


gmail_gmail_folderfirst() {
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
		--exclude "blanc\ $" --exclude Gmail \
                --justfolders --folderfirst INBOX --folderfirst zz  --folderlast "[Gmail]/All Mail" --debug
}


gmail_gmail_INBOX() {
                $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --folder INBOX --debugflags
		#--dry # --debug --debugimap # --authmech1 LOGIN
}

gmail_gmail_3_delete() {
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 imapsync.gl@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 gilles.lamiral@gmail.com \
                --passfile2 ../../var/pass/secret.gilles_gmail \
                --folder '[Gmail]/All Mail' --delete1
		# '[Gmail]/All Mail' is not expunge by default!

}

gmail_gmail_4_tls() {
                ! ping -c1 imap.gmail.com || ! $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1  \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --ssl2 --tls2 --port2 993 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --folder INBOX 
		#--dry # --debug --debugimap # --authmech1 LOGIN
}


gmail_gmail_5_exclude_only_Gmail() {

                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --nofoldersizes --folderrec "[Gmail]" --exclude "\[Gmail\]$"
}

gmail_gmail_6_search() {
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --gmail1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --gmail2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --folder INBOX --search 'X-GM-RAW "has:attachment"'
}

gmail_gmail_7_search() {
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --folder "[Gmail]/All Mail" --search 'X-GM-RAW "Analysez lalala performances"' 
}

gmail_gmail_8_search() { 
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --gmail1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --gmail2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --folder Test --nofoldersizes --debugimap \
                --search 'X-GM-RAW "label:Important label:Test"' 

}

gmail_gmail_9_search_X_GM_LABELS() {
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --gmail1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --gmail2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --folder Test --nofoldersizes --debugimap \
                --search 'X-GM-LABELS "Important"'  
}

gmail_gmail_10_search_drafts() {
                ! ping -c1 imap.gmail.com || $CMD_PERL ./imapsync \
                --gmail1 \
                --user1 gilles.lamiral@gmail.com \
                --passfile1 ../../var/pass/secret.gilles_gmail \
                --gmail2 \
                --user2 imapsync.gl@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl_gmail \
                --nofoldersizes \
                --folderfirst '[Gmail]/Drafts' --debuglabels --dry  \
                --folder Test --folder '[Gmail]/Drafts' 
}




gmail_gl_gl2_sslargs()
{
        $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --ssl1 \
                --user1 imapsync.gl@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl_gmail \
                --host2 imap.gmail.com \
                --ssl2 \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --justlogin --sslargs1 SSL_version=SSLv3 --sslargs1 SSL_verify_mode=0
}


# imapsync.gl@gmail.com   
# imapsync.gl0@gmail.com == Source only account for imapsync
# imapsync.gl1@gmail.com == Source account for imapsync.gl2@gmail.com with 
#                                               --subfolder2 "Archive/Bob"
#                                               --subfolder2 "Archive/Zuz"
#                           Destination account from imapsync.gl3@gmail.com with
#                                               --subfolder1 "Archive/Bob"

# imapsync.gl2@gmail.com == Destination account --subfolder2 "Archive/Bob" from imapsync.gl1@gmail.com
#                                               --subfolder2 "Archive/Zuz" from imapsync.gl1@gmail.com
# imapsync.gl3@gmail.com == 


sendtestmessage_gl0()
{
        sendtestmessage imapsync.gl0@gmail.com
}


sendtestmessage_gl1()
{
        sendtestmessage imapsync.gl1@gmail.com
}

gmail_gl1_gl2_labels()
{
        #sendtestmessage imapsync.gl1@gmail.com
        $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl1@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl1_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --exclude "\[Gmail\]" \
                --synclabels --resynclabels --debug --debuglabels # --dry
}

gmail_gl1_gl2_labels_subfolder2()
{
        #sendtestmessage imapsync.gl1@gmail.com
        
        # The backup
        $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl1@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl1_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --synclabels  --resynclabels --debuglabels --delete2\
                --subfolder2 "Archive/Bob"  --nofoldersizes --gmail1 --gmail2 --dry # --exclude "\[Gmail\]" 

        return
        
        #sendtestmessage imapsync.gl1@gmail.com
        $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl1@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl1_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --gmail1 --gmail2 --synclabels --resynclabels --delete2 --folder INBOX --subfolder2 "Archive/Zuz"
}

gmail_gl2_gl3_labels_after_a_subfolder2_from_host1()
{
        # A second backup, standard this one (no --subfolder2)
        $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl2@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl2_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl3@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl3_gmail \
                --synclabels --resynclabels --folderrec "Archive/Bob" --gmail1 --gmail2 --dry
}

gmail_gl3_gl1_labels_subfolder1()
{
        # The restoration process
        $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl3@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl3_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl1@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl1_gmail \
                --subfolder1 "Archive/Bob" --debuglabels --resynclabels --nofoldersizes --justfolders #--dry 
}

gmail_deuscustoms()
{
$CMD_PERL ./imapsync \
--host1 imap.gmail.com --user1 "test1@deuscustoms.com" --passfile1 '../../var/pass/test1@deuscustoms.com' \
--host2 imap.gmail.com --user2 "test2@deuscustoms.com" --passfile2 '../../var/pass/test2@deuscustoms.com' \
--subfolder2 "Archived accounts/Test User 1" \
--exclude "\[Gmail\]" --folderlast INBOX  \
--debuglabels --resynclabels --synclabels --nofoldersizes #--dry
}

gmail_gl1_gl2_appendlimit()
{
        #sendtestmessage imapsync.gl1@gmail.com
        $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl1@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl1_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --gmail1 --gmail2 --nofoldersizes --justlogin
}



gmail_gl1_gl2_maxsize_over_appendlimit()
{
        #sendtestmessage imapsync.gl1@gmail.com
        $CMD_PERL ./imapsync \
                --host1 imap.gmail.com \
                --user1 imapsync.gl1@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl1_gmail \
                --host2 imap.gmail.com \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --gmail1 --gmail2 --nofoldersizes \
                --justlogin --maxsize 999_999_999_999
}

gmail_gl2_gl2_move_All_Mail_Trash()
{
        #sendtestmessage imapsync.gl1@gmail.com
        $CMD_PERL ./imapsync \
                --user1 imapsync.gl2@gmail.com \
                --passfile1 ../../var/pass/secret.imapsync.gl2_gmail \
                --user2 imapsync.gl2@gmail.com \
                --passfile2 ../../var/pass/secret.imapsync.gl2_gmail \
                --gmail1 --gmail2 \
                --folder '[Gmail]/Tous les messages' \
                --f1f2 '[Gmail]/Tous les messages=[Gmail]/Corbeille'
}



yahoo_xxxx_login()
{
                ! ping -c1 imap.mail.yahoo.com || $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 $HOST2 \
                --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin 
}

yahoo_xxxx_login_tls() {
                # tls1 no longer works on Yahoo
                ! ping -c1 imap.mail.yahoo.com || ! $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --tls1 --timeout1 5 \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 $HOST2 \
                --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin 
}



yahoo_xxxx() {
# Yahoo works only with ssl (november 2011)
# Could do plain port 143 before
                ! ping -c1 imap.mail.yahoo.com || $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 $HOST2 \
                --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --addheader --exclude Archive
}

yahoo_fail_UNAVAILABLE() { 
# Those are messages from yahoo:
# Err 1/11: - msg Archive/470002 {0} S[12903] F[$NotJunk] I[25-Oct-2016 00:19:28 +0000] could not be fetched: 29 NO [UNAVAILABLE] UID FETCH Server error while fetching messages
# Update 2018/5/5: it now works well on those messages
        ! ping -c1 imap.mail.yahoo.com || $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 $HOST2 \
                --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --addheader --folder Archive
}

yahoo_search_SENTBEFORE()
{
        ! ping -c1 imap.mail.yahoo.com || $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 $HOST2 \
                --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --search "SENTBEFORE 1-Jan-2019"
}

yahoo_search_SENTAFTER()
{
        # SENTAFTER is plain wrong, so it should fail!
        ! ping -c1 imap.mail.yahoo.com || ! $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 $HOST2 \
                --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --search "SENTAFTER 1-Jan-2019" --folder Inbox --dry --debugimap1
}

yahoo_search_SENTSINCE()
{
        # SENTAFTER is wrong, it should fail!
        ! ping -c1 imap.mail.yahoo.com || $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 $HOST2 \
                --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --search "SENTSINCE 1-Jan-2019" --folder Inbox --dry --debugimap1
}

yahoo_search_ALL_Inbox()
{
        # SENTAFTER is wrong, it should fail!
        ! ping -c1 imap.mail.yahoo.com || $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 $HOST2 \
                --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --search "ALL" --folder Inbox --dry 
}


yahoo_yahoo_Inbox()
{
        # SENTAFTER is wrong, it should fail!
        ! ping -c1 imap.mail.yahoo.com || $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 imap.mail.yahoo.com \
                --user2 glamiral \
                --passfile2 ../../var/pass/secret.gilles_yahoo \
                --folder Inbox --dry --debugimap1
}

yahoo_yahoo_search_ALL_Inbox()
{
        # SENTAFTER is wrong, it should fail!
        ! ping -c1 imap.mail.yahoo.com || $CMD_PERL ./imapsync \
                --host1 imap.mail.yahoo.com \
                --user1 glamiral \
                --passfile1 ../../var/pass/secret.gilles_yahoo \
                --host2 imap.mail.yahoo.com \
                --user2 glamiral \
                --passfile2 ../../var/pass/secret.gilles_yahoo \
                --folder Inbox --dry --debugimap1 --search "ALL" 
}





yahoo_all() {
        yahoo_xxxx_login_tls    || return 1
        yahoo_xxxx_login        || return 1
        yahoo_xxxx              || return 1
        yahoo_fail_UNAVAILABLE  || return 1
        yahoo_search_SENTSINCE  || return 1
        yahoo_search_ALL_Inbox  || return 1
        yahoo_yahoo_Inbox       || return 1
        yahoo_search_SENTBEFORE || return 1
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
                --folder INBOX --regextrans2 's/INBOX/copy/' 
}

dkimap_1() {
                $CMD_PERL  ./imapsync \
                --host1 Mail.fourfrontsales.com --user1 dktest \
                --passfile1 ../../var/pass/secret.dktest \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --folder INBOX/dkimap --regextrans2 's/INBOX.INBOX./INBOX./'  \
		--foldersize --nouid1
}

ll_justlogin() {
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin 
}

ll_justlogin_notls() {
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --notls1 --notls2 
}

ll_justlogin_nocompress() {
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 titi \
                --passfile2 ../../var/pass/secret.titi \
                --justlogin --nocompress2 
}




ll_justlogin_backslash_char() {
# Look in the file ../../var/pass/secret.tptp to see 
# strange \ character behavior
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 tptp@est.belle \
                --passfile2 ../../var/pass/secret.tptp \
                --justlogin 
}

ll_justlogin_dollar_char() {
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 dollar \
                --passfile2 ../../var/pass/secret.dollar \
                --justlogin --showpasswords --debugimap2
}

ll_justlogin_equal_char() {
                $CMD_PERL  ./imapsync \
                --host1 $HOST1 --user1 tata \
                --passfile1 ../../var/pass/secret.tata \
                --host2 $HOST2 --user2 equal \
                --passfile2 ../../var/pass/secret.equal \
                --justlogin --debugimap2
}




ll_usecache()
{
        if can_send; then
                sendtestmessage
        fi

        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --usecache --nofoldersizes \
         --folder INBOX 
}

ll_usecache_INBOX() {
        if can_send; then
                sendtestmessage
        else
                :
        fi

        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --usecache \
         --folder INBOX 
}


ll_usecache_all()
{
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --usecache --nofoldersizes
}

ll_usecache_bracket() {
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --usecache --nofoldersizes --debugcache --folder "INBOX.[bracket]" 
}


# In mandatory_tests
ll_nousecache() {
        if can_send; then
                sendtestmessage
        else
                :
        fi
	
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --nousecache --nofoldersizes \
         --folder INBOX 
}






ll_usecache_noheader() {
        if can_send; then
                sendtestmessage
        else
                :
        fi
	
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --usecache \
         --folder INBOX --useheader ''
}

ll_usecache_debugcache() {
        if can_send; then
                sendtestmessage
        else
                :
        fi
	
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --usecache --nofoldersizes \
         --folder INBOX --useheader '' --debugcache
}

ll_usecache_debugcache_useuid() {
        if can_send; then
                sendtestmessage
        else
                :
        fi
	
        $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
         --usecache --nofoldersizes \
         --folder INBOX --useheader '' --debugcache --useuid
}

ll_useuid_INBOX() 
{
        if can_send; then
                sendtestmessage
        else
                :
        fi
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX \
        --delete2 \
        --useuid

}

# In mandatory_tests
ll_useuid() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.useuid \
        --delete2 \
        --useuid
}

ll_useuid_all() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --delete2 --useuid --nofoldersizes
}

# In mandatory_tests
ll_useuid_nousecache() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX.useuid \
        --useuid --nousecache --debugcache
        echo 'rm /home/vmail/titi/.yop.yap/cur/*'
}

ll_fastio() 
{
        time -p $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --fastio1 --fastio2
}

ll_nofastio() 
{
        time -p $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 titi \
        --passfile2 ../../var/pass/secret.titi \
        --folder INBOX --nofastio1 --nofastio2
}

l_office365()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --folder INBOX --tmpdir /var/tmp --usecache --regextrans2 's/INBOX/tata/' --delete2 
}

l_office365_deleted_flag() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --folder INBOX.flags --tmpdir /var/tmp --regextrans2 's/INBOX/tata/'  --debugflags
}

l_office365_flagged_flag() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --office2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --folder INBOX.flags --tmpdir /var/tmp --regextrans2 's/INBOX/tata/'  --debugflags
}

l_office365_noregexmess() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --office2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --justbanner  --noregexmess
}


l_exchange2_flagged_flag() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 outlook.office365.com \
        --exchange2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --regextrans2 's/INBOX/tata/' --nofoldersizes \
        --folder INBOX.flags  --debugflags 
}

l_exchange2_flagged_noregexflag() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 outlook.office365.com \
        --exchange2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --regextrans2 's/INBOX/tata/' --nofoldersizes \
        --folder INBOX.flags  --debugflags --noregexflag
}

l_exchange2_noregexmess_noregexflag() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 outlook.office365.com \
        --exchange2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --justbanner  --noregexmess --noregexflag
}


l_office365_SSL_verify_mode()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --justlogin --sslargs2 SSL_verify_mode=1
}

office1_office2()
{
        $CMD_PERL ./imapsync \
        --office1   \
	--user1 gilles.lamiral@outlook.com \
	--passfile1 ../../var/pass/secret.outlook.com \
        --office2   \
	--user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
	--justfolders
}

office1_office2_sentbefore()
{
        $CMD_PERL ./imapsync \
        --office1   \
	--user1 gilles.lamiral@outlook.com \
	--passfile1 ../../var/pass/secret.outlook.com \
        --office2   \
	--user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --folder Sent --search "SENTBEFORE 31-Dec-2013" --debugimap
}




office1_office2_noexclude()
{
        $CMD_PERL ./imapsync \
        --office1   \
	--user1 gilles.lamiral@outlook.com \
	--passfile1 ../../var/pass/secret.outlook.com \
        --office2   \
	--user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
	--justfolders --noexclude
}



office365_justconnect_tls_SSL_verify_mode_1()
{
        $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com  --ssl1 --user1 gilles.lamiral@outlook.com \
        --passfile1 ../../var/pass/secret.outlook.com \
        --host2 outlook.office365.com  --tls2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --justconnect --sslargs2 SSL_verify_mode=1
}


office365_justlogin_ssl1_ssl2()
{
        $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com --ssl1 --user1 gilles.lamiral@outlook.com \
        --passfile1 ../../var/pass/secret.outlook.com \
        --host2 imap.outlook.com   --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --justlogin 
}

outlook_login()
{
        office365_justlogin_ssl1_ssl2
}

office365_justlogin_tls()
{
        $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com  --ssl1 --user1 gilles.lamiral@outlook.com \
        --passfile1 ../../var/pass/secret.outlook.com \
        --host2 imap.outlook.com       --tls2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --justlogin 
}


office365_justlogin_tls2_office365()
{
        $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com  --ssl1 --user1 gilles.lamiral@outlook.com \
        --passfile1 ../../var/pass/secret.outlook.com \
        --host2 outlook.office365.com  --tls2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --justlogin 
}

office365_justlogin_ssl2_tls2_office365()
{
# Should produce "BAD Command received in Invalid state."
        $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com  --ssl1        --user1 gilles.lamiral@outlook.com \
        --passfile1 ../../var/pass/secret.outlook.com \
        --host2 outlook.office365.com  --tls2 --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --justlogin 
        test "$?" = "$EXIT_TLS_FAILURE"
}

office365_justlogin_nossl2_notls2_office365()
{
# Should also produce "BAD Command received in Invalid state."
        ! $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com  --ssl1        --user1 gilles.lamiral@outlook.com \
        --passfile1 ../../var/pass/secret.outlook.com \
        --host2 outlook.office365.com  --notls2 --nossl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --justlogin 
}



office365_justconnect_stunnel_ks() {
        $CMD_PERL ./imapsync \
        --host1 outlook.office365.com --ssl1 \
        --host2 ks.lamiral.info --port2 144 \
        --justconnect
}

office365_justconnect_stunnel_i005() {
        $CMD_PERL ./imapsync \
        --host1 outlook.office365.com --ssl1 \
        --host2 i005.lamiral.info --port2 144 \
        --justconnect
}


office365_justconnect_inet4_inet6()
{
        echo force ipv4
        $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com \
        --host2 outlook.office365.com \
        --justconnect --inet4

		echo
		echo force ipv6
        $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com \
        --host2 outlook.office365.com \
        --justconnect --inet6

		echo
        # outlook.office365.com gives ipv6 2a01:111:f400:2fa2::2
        echo this one should fail but is does not
        $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com  \
        --host2  2603:1026:4:51::2  \
        --justconnect --inet4

		echo
        # outlook.office365.com gives ipv4 40.101.42.82
        echo this one should fail but is does not
        $CMD_PERL ./imapsync \
        --host1 imap-mail.outlook.com \
        --host2 40.101.42.82  \
        --justconnect --inet6

		echo
        # outlook.office365.com gives ipv6 2603:1026:4:50::2
        echo this one should succeed
        $CMD_PERL ./imapsync \
        --host1 2603:1026:4:51::2  \
        --host2 imap-mail.outlook.com  \
        --justconnect
}

inet4_inet6() 
{
		echo
        # outlook.office365.com gives ipv6 2603:1026:4:50::2
        # outlook.office365.com gives ipv4 52.97.129.66

        echo this one should succeed
        $CMD_PERL ./imapsync \
        --host1 2603:1026:4:50::2  \
        --host2 52.97.129.66  \
        --justconnect 

        echo this one should do ipv6
        $CMD_PERL ./imapsync \
        --host1 outlook.office365.com  \
        --host2 outlook.office365.com  \
        --justconnect --inet6
        
        echo this one should do ipv4
        $CMD_PERL ./imapsync \
        --host1 outlook.office365.com  \
        --host2 outlook.office365.com  \
        --justconnect --inet4
        
}




l_office365_bigfolders()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --tmpdir /var/tmp --useuid --include Junk.20
}



l_office365_maxline()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --tmpdir /var/tmp --usecache --include Junk.2013 --maxlinelength 16000 --debugmaxlinelength
}

l_office365_maxline_2()
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
	--folder INBOX  --regextrans2 's/INBOX/tata/' \
	--minmaxlinelength 8000 --debugmaxlinelength
}

l_office365_maxline_3()
{
        # It fails at 10240. So the fix is to cut at 10239
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 longlines \
        --passfile1 ../../var/pass/secret.longlines \
        --host2 imap-mail.outlook.com --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --tmpdir /var/tmp --usecache \
	--folder INBOX  --regextrans2 's/INBOX/longlines/' \
	--debugmaxlinelength --errorsmax 1 --regexmess 's,(.{10239}),$1\r\n,g'
}

ll_empty_longlines()
{
        ./imapsync \
        --host1 $HOST1 --user1 longlines --passfile1 ../../var/pass/secret.longlines \
        --host2 $HOST1 --user2 longlines --passfile2 ../../var/pass/secret.longlines \
        --delete1 --noexpungeaftereach --delete1emptyfolders
}

# Only available on ks2 (filtered by a firewall)
l_exchange_maxline() 
{
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 correu.quopiam.com --ssl2 --user2 utest@quopiam.com \
        --passfile2 ../../var/pass/secret.quopiam.com \
        --tmpdir /var/tmp --usecache \
	--folder INBOX  --regextrans2 's/INBOX/longlines/' \
	--minmaxlinelength 10000 --maxlinelength 11000 --debugmaxlinelength 
}

# In mandatory_tests
fuzz_basic() {
        zzuf -E '^' $CMD_PERL  ./imapsync 
}

# In mandatory_tests
fuzz_network() {
        zzuf -E '^' -d -n $CMD_PERL  ./imapsync \
         --host1 $HOST1 --user1 tata \
         --passfile1 ../../var/pass/secret.tata \
         --host2 $HOST2 --user2 titi \
         --passfile2 ../../var/pass/secret.titi \
	 --timeout 5 
}

# general tests end

##########################
# specific tests
##########################


free_ssl() {
        $CMD_PERL ./imapsync \
        --host1 imap.free.fr --user1 gilles.lamiral@free.fr --passfile1 ../../var/pass/secret.gilles_free \
        --host2 imap.free.fr --user2 gilles.lamiral@free.fr --passfile2 ../../var/pass/secret.gilles_free \
        --justlogin --ssl1 --ssl2  
}

# xgenplus still ok on Wed Apr  3 15:36:09 CEST 2019
xgenplus() {
        $CMD_PERL ./imapsync \
        --host1 imap.dataone.in --user1 imapsynctest@dataone.in  \
        --passfile1 ../../var/pass/secret.xgenplus \
        --host2 imap.dataone.in --user2 imapsynctest@dataone.in \
        --passfile2 ../../var/pass/secret.xgenplus \
        --sep1 / --sep2 / --prefix1 "" --prefix2 ""  --dry 
}


xgenplus_feed() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap.dataone.in --user2 imapsynctest@dataone.in \
        --passfile2 ../../var/pass/secret.xgenplus \
        --sep2 / --prefix2 "" \
        --include "Junk.2013" --regextrans2 "s,Junk.2013,Junk," --dry 
}

xgenplus_few() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap.dataone.in --user2 imapsynctest@dataone.in \
        --passfile2 ../../var/pass/secret.xgenplus \
        --sep2 / --prefix2 "" \
        --include "few_emails"  --dry 
}


firstclass() {
        $CMD_PERL ./imapsync \
        --host1 mail.una.ab.ca \
        --user1 glamiral --passfile1 ../../var/pass/secret.firstclass \
        --host2 mail.una.ab.ca \
        --user2 glamiral --passfile2 ../../var/pass/secret.firstclass \
        --dry --useuid --debugcontent
}

firstclass_fullfill() {
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 mail.una.ab.ca \
        --user2 glamiral --passfile2 ../../var/pass/secret.firstclass \
        --debugcontent \
        --folder INBOX.few_emails --f1f2 'INBOX.few_emails=INBOX'
}


Alessandro_error_11() 
{
        # $CMD_PERL  ./imapsync \
         # --host1 $HOST1 --user1 tata \
         # --passfile1 ../../var/pass/secret.tata \
         # --host2 $HOST2 --user2 titi \
         # --passfile2 ../../var/pass/secret.titi \
        # --folder INBOX.error_11 --debugcontent --nodry --nodry1 --pipemess 'cat /g/Alessandro_error_11.txt'

        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com \
        --passfile2 ../../var/pass/secret.outlook.com \
        --folder INBOX.error_11 --debugcontent --nodry --nodry1 --pipemess 'cat /g/Alessandro_error_11.txt' \
        --regexmess "s{\QSubject: =?TELETEX?Q?Fw=3APresentation_Storia_dell=5C=27Informatica?=\E}{Subject: Presentation Storia dell'Informatica}"

# Subject: =?TELETEX?Q?Fw=3APresentation_Storia_dell=5C=27Informatica?=
# Subject: Presentation Storia dell'Informatica
        #--pipemess W/tools/fix_email_for_exchange.py 
        #--pipemess 'reformime -r7'

}

# End of specific tests

huge_folder()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --include INBOX.Junk.2010 \
        --tmpdir /var/tmp  --debugmemory || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}

huge_folder_headers_ALL()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --include INBOX.Junk.2010 \
        --tmpdir /var/tmp --useheader ALL  --debugmemory || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}

huge_folder_2018()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 gilles@est.belle \
        --passfile2 ../../var/pass/secret.gilles_mbox \
        --folder INBOX.Junk \
        --f1f2 INBOX.Junk=INBOX.Junk.2018 \
        --search "SENTBEFORE 1-Jan-2019" \
        --tmpdir /var/tmp --usecache  --delete1
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}


huge_message_ks()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 tete \
        --passfile2 ../../var/pass/secret.tete \
        --folder  INBOX --minsize 100000000 \
        --tmpdir /var/tmp --debugmemory --nofoldersizes
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
    echo3 'rm -f /home/tete/Maildir/cur/*'
}


huge_folder_ks()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 tata \
        --passfile1 ../../var/pass/secret.tata \
        --host2 $HOST2 --user2 tete \
        --passfile2 ../../var/pass/secret.tete \
        --include Junk.2010 \
        --tmpdir /var/tmp 
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
    echo3 'rm -f /home/tete/Maildir/.Junk.2010/cur/*'
}




huge_folder_useuid()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --include INBOX.Junk.20 --foldersizes \
        --useuid --tmpdir /var/tmp --delete2 || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}




huge_folder_sizes_only()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --justfoldersizes  --folder INBOX.Junk.2010 || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}

huge_folder_fast()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --folder INBOX.Junk.2010 \
        --fast || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}

huge_folder_fast2()
{
    date1=`date`
    { $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --folder INBOX.Junk \
        --fast || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
    echo3 'rm -f /home/vmail/tete/.Junk/cur/*'
}


dprof_justfoldersizes()
{
    date1=`date`
    { $CMD_PERL -d:DProf ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --justfoldersizes  --folder INBOX.Junk || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
    mv tmon.out dprof_justfoldersizes_tmon.out
    dprofpp -O 30    dprof_justfoldersizes_tmon.out
    dprofpp -O 30 -I dprof_justfoldersizes_tmon.out
}


bigfolder()
{
        date1=`date`
        date1epoch=`date +%s`
         
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --foldersizes  --folder INBOX.Junk.2010 --usecache 
        
        date2=`date`
        date2epoch=`date +%s`

        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --foldersizes  --folder INBOX.Junk.2010
        
        date3=`date`
        date3epoch=`date +%s`
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --foldersizes  --folder INBOX.Junk.2010 --usecache 
        
        date4=`date`
        date4epoch=`date +%s`
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --foldersizes  --folder INBOX.Junk.2010
        
        date5=`date`
        date5epoch=`date +%s`
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --foldersizes  --folder INBOX.Junk.2010 --usecache 
        
        date6=`date`
        date6epoch=`date +%s`
        $CMD_PERL ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --foldersizes  --folder INBOX.Junk.2010
        
        date7=`date`
        date7epoch=`date +%s`
        
        diff_21=`expr $date2epoch - $date1epoch`
        diff_32=`expr $date3epoch - $date2epoch`
        diff_43=`expr $date4epoch - $date3epoch`
        diff_54=`expr $date5epoch - $date4epoch`
        diff_65=`expr $date6epoch - $date5epoch`
        diff_76=`expr $date7epoch - $date6epoch`
        diff_32_21=`expr $diff_32 - $diff_21`
        diff_54_43=`expr $diff_54 - $diff_43`
        diff_76_65=`expr $diff_76 - $diff_65`
        echo "[$date1] [$date2] [$date3] [$date4] [$date5] [$date6] [$date7]" | tee -a bigfolder.txt
        echo "diff [$diff_21] [$diff_32] [$diff_43] [$diff_54] [$diff_65] [$diff_76]" | tee -a bigfolder.txt
        echo "diff cache pas cache [$diff_32_21] [$diff_54_43] [$diff_76_65]" | tee -a bigfolder.txt
        echo >> bigfolder.txt
}





dprof_bigfolder()
{
    date1=`date`
    { $CMD_PERL -d:DProf ./imapsync \
        --host1 $HOST1 --user1 gilles@est.belle \
        --passfile1 ../../var/pass/secret.gilles_mbox \
        --host2 $HOST2 --user2 tete@est.belle \
        --passfile2 ../../var/pass/secret.tete \
        --nofoldersizes  --folder INBOX.03_imapsync.imapsync_list || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
    mv tmon.out      dprof_bigfolder_tmon.out
    dprofpp -O 30    dprof_bigfolder_tmon.out
    dprofpp -O 30 -I dprof_bigfolder_tmon.out
}

dprof_bigmail() 
{
    date1=`date`
    { $CMD_PERL -d:DProf ./imapsync \
      --host1 $HOST1  --user1 tata \
      --passfile1 ../../var/pass/secret.tata \
      --host2 $HOST2 --user2 titi \
      --passfile2 ../../var/pass/secret.titi \
      --folder INBOX.bigmail --dry --maxlinelength 8888
      echo 'sudo sh -c "rm -v /home/vmail/titi/.bigmail/cur/*"' || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
    mv tmon.out      W/dprof_bigmail_tmon.out
    dprofpp -O 30    W/dprof_bigmail_tmon.out
    dprofpp -O 30 -I W/dprof_bigmail_tmon.out
}

nytprof_bigmail() 
{
    date1=`date`
    { $CMD_PERL -d:NYTProf ./imapsync \
      --host1 $HOST1  --user1 tata \
      --passfile1 ../../var/pass/secret.tata \
      --host2 $HOST2 --user2 titi \
      --passfile2 ../../var/pass/secret.titi \
      --folder INBOX.bigmail --dry --maxlinelength 8888
      echo 'sudo sh -c "rm -v /home/vmail/titi/.bigmail/cur/*"' || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
}

ll_nytprof() 
{
    date1=`date`
    # one time without NYTProf
    { $CMD_PERL ./imapsync \
      --host1 $HOST1  --user1 tata \
      --passfile1 ../../var/pass/secret.tata \
      --host2 $HOST2 --user2 titi \
      --passfile2 ../../var/pass/secret.titi
    }
    date2=`date`
    # then one time with NYTProf
    { $CMD_PERL -d:NYTProf ./imapsync \
      --host1 $HOST1  --user1 tata \
      --passfile1 ../../var/pass/secret.tata \
      --host2 $HOST2 --user2 titi \
      --passfile2 ../../var/pass/secret.titi
    }
    date3=`date`
    echo3 "begin: [$date1]"
    echo3 "first: [$date2]"
    echo3 "end:   [$date3]"
}



dprof2_bigmail()
{
    date1=`date`
    { $CMD_PERL -d:Profile ./imapsync \
      --host1 $HOST1  --user1 tata \
      --passfile1 ../../var/pass/secret.tata \
      --host2 $HOST2 --user2 titi \
      --passfile2 ../../var/pass/secret.titi \
      --folder INBOX.bigmail --debugmemory --dry
      echo 'sudo sh -c "rm -v /home/vmail/titi/.bigmail/cur/*"' || \
    true
    }
    date2=`date`
    echo3 "[$date1] [$date2]"
    mv prof.out      W/dprof2_bigmail_tmon.out
}

curl_online_args()
{
        curl -v --data 'host1=test1.lamiral.info;user1=test1;password1=secret1;host2=test2.lamiral.info;user2=test2;password2=secret2;simulong=2' \
                https://imapsync.lamiral.info/cgi-bin/imapsync
}

curl_online_testslive()
{
        curl -v --data 'testslive=1;simulong=2' https://imapsync.lamiral.info/cgi-bin/imapsync
}



curl_online_args_pidfile()
{
        curl -v --data"host1=test1.lamiral.info;user1=test1;password1=secret1;host2=test2.lamiral.info;user2=test2;password2=secret2;pidfile=/tmp/curl_online_args_pidfile_$$.txt" \
                https://imapsync.lamiral.info/cgi-bin/imapsync
}

curl_online_args_nolog()
{
        curl -v --data 'host1=test1.lamiral.info;user1=test1;password1=secret1;host2=test2.lamiral.info;user2=test2;password2=secret2;justbanner=1;log=' \
                https://lamiral.info/cgi-bin/imapsync
}

curl_online_args_nolog_2()
{
        curl -v --data 'host1=test1.lamiral.info;user1=test1;password1=secret1;host2=test2.lamiral.info;user2=test2;password2=secret2;justbanner=1;log=0' \
                https://lamiral.info/cgi-bin/imapsync
}

curl_online_justbanner()
{
        curl -v --data 'host1=test1.lamiral.info;user1=test1;password1=secret1;host2=test2.lamiral.info;user2=test2;password2=secret2;simulong=0.7;justbanner=1' \
                https://lamiral.info/cgi-bin/imapsync
}


curl_online_file()
{
        cat > W/tmp/cred.txt <<EOF
host1=test1.lamiral.info;
user1=test1;
password1=secret1;
host2=test2.lamiral.info;
user2=test2;
password2=secret2;
simulong=2;
dry=1;

EOF
        curl -v --data '@W/tmp/cred.txt' \
                https://imapsync.lamiral.info/cgi-bin/imapsync
}

curl_online_args_json()
{
        # DO NOT WORK AT ALL
        ! curl -v --data '{ "testslive":"1" }' -H "Content-Type: application/json"  \
                https://imapsync.lamiral.info/cgi-bin/imapsync
}


#  * 1.810 https://tools.controlpanel.si/imapsync/ CGI https://tools.controlpanel.si/cgi-bin/imapsync
#  * 1.882 https://tools.intertune.io/imapsync/X/  CGI https://tools.intertune.io/cgi-bin/imapsync
#  * 1.882 https://imapsync.whc.ca/                CGI https://imapsync.whc.ca/cgi-bin/imapsync
#  * 1.925 https://imapsync.boomhost.com/          CGI https://imapsync.boomhost.com/cgi-bin/imapsync 
#  * 1.977 https://imapcopy.webhosting4u.gr/       CGI https://imapcopy.webhosting4u.gr/cgi-bin/imapsync
#  * 1.991 https://imapsync.nl/                    CGI https://imapsync.nl/cgi-bin/imapsync
#  * 1.998 https://mailsync.timetakernet.info/     CGI https://mailsync.timetakernet.info/cgi-bin/imapsync

#Detected by releasecheck:
#  * 1.957 http://migracao.hahost.com.br/migrar2.html    CGI http://migracao.hahost.com.br/cgi-bin/imapsync
#  * 1.967                                               CGI https://jcenter.nara-edu.ac.jp/cgi-bin/imapsync
#  * 1.973 http://77.68.7.106/                           CGI http://77.68.7.106/cgi-bin/imapsync
#  * 1.979                                               CGI http://mail2.nara-edu.ac.jp/cgi-bin/imapsync
#  * 1.979                                               CGI https://imapsync.bepulse.com/cgi-bin/imapsync
#  * 1.990 https://transfer.keliweb.com/X/               CGI https://transfer.keliweb.com/cgi-bin/imapsync
#  * 1.998                                               CGI https://web-tools.na.icb.cnr.it/cgi-bin/imapsync
#  * 1.998                                               CGI https://140.164.23.4/cgi-bin/imapsync

#  * ?.??? https://app.migrationwizard.co.uk/      CGI 404, deep into https://app.migrationwizard.co.uk/sync.php

curl_online_external()
{
# curl 
# -v verbose
# -s silent
        for imapsync in \
                https://imapsync.lamiral.info/cgi-bin/imapsync      \
                https://tools.controlpanel.si/cgi-bin/imapsync      \
                https://tools.intertune.io/cgi-bin/imapsync         \
                https://imapsync.whc.ca/cgi-bin/imapsync            \
                https://imapsync.boomhost.com/cgi-bin/imapsync      \
                https://imapcopy.webhosting4u.gr/cgi-bin/imapsync   \
                https://imapsync.nl/cgi-bin/imapsync                \
                https://mailsync.timetakernet.info/cgi-bin/imapsync \
                https://jcenter.nara-edu.ac.jp/cgi-bin/imapsync     \
                https://imapsync.bepulse.com/cgi-bin/imapsync       \
                https://transfer.keliweb.com/cgi-bin/imapsync       \
                https://web-tools.na.icb.cnr.it/cgi-bin/imapsync    \
                https://140.164.23.4/cgi-bin/imapsync               \
                ; do
                curl -k -s --data 'justconnect=1;host1=mail.unionstrategiesinc.com;user1=a;user2=a;host2=mail5.unionstrategiesinc.com;simulong=2' \
                        $imapsync
                #sleep 2
        done 
}


##########################
##########################

# Tests list

mandatory_tests='
no_args

option_version
option_tests
option_tests_in_var_tmp
option_tests_in_var_tmp_sub
option_testsdebug
option_releasecheck
option_noreleasecheck
option_bad_delete2
option_extra_arguments
option_extra
passfile1_noexist
passfile2_noexist
passwords_masked
passwords_not_masked
first_sync_dry
first_sync
ll
ll_host_sanitize
pidfile_well_removed
pidfile_bad
ll_pidfilelocking
test_tail
justbanner
nomodules_version
xxxxx_gmail
gmail_xxxxx
gmail
gmail_gmail
gmail_gmail_INBOX
gmail_gmail_folderfirst
gmail_glX_all_justlogin

yahoo_xxxx_login_tls
yahoo_xxxx_login
yahoo_xxxx
yahoo_fail_UNAVAILABLE

free_ssl
office365_justconnect_inet4_inet6
office365_justconnect_tls_SSL_verify_mode_1
ll_unknow_option
ll_ask_password
ll_env_password
ll_bug_folder_name_with_blank
ll_skipcrossduplicates_usecache
ll_timeout
ll_timeout1_timeout2
ll_timeout_very_small
ll_folder
ll_folder_noexist
ll_folder_mixfolders
ll_nocheckselectable
ll_checkselectable
ll_checkselectable_nb_folders
ll_nocheckfoldersexist
ll_checkfoldersexist
ll_subfolder2
ll_subfolder1
ll_subfolder1_INBOX_SUB
ll_subfolder1_DOES_NOT_EXIST
ll_oneemail
ll_buffersize
ll_justfolders
ll_justfolders_delete1emptyfolders
ll_justfolders_skipemptyfolders
ll_f1f2_01
ll_prefix12
ll_nosyncinternaldates
ll_idatefromheader
ll_folder_rev
ll_subscribed
ll_nosubscribe
ll_justfoldersizes
ll_justfoldersizes_noexist
ll_authmd5
ll_authmd51
ll_authmd52
ll_noauthmd5
ll_maxage
ll_maxsize
ll_skipsize
ll_skipheader
ll_include
ll_exclude
ll_exclude_INBOX
ll_regextrans2
ll_sep2
ll_bad_login
ll_authentication_failure_user1
ll_authentication_failure_user2
ll_authentication_failure_user12
ll_bad_host1
ll_bad_host2
ll_bad_host12
ll_bad_host_ssl
ll_useheader
ll_useheader_noheader
ll_regexmess
ll_regexmess_8bit_X
ll_regexmess_bad_regex
ll_regexmess_add_header
ll_regexmess_add_header_path
ll_regexmess_scwchu
ll_skipmess
ll_skipmess_8bits
ll_skipmess_Content_Type_Message_partial
ll_pipemess_nocmd
ll_pipemess_false
ll_pipemess_true
ll_pipemess
ll_pipemess_catcat
ll_flags
ll_resyncflags
ll_noresyncflags
ll_syncflagsaftercopy
ll_regex_flag
ll_regex_flag_bad
ll_regex_flag_keep_only
ll_justconnect
ll_justconnect_ipv6
ll_justconnect_ipv6_nossl
ll_justhost1
ll_justhost2
ll_justlogin
ll_justconnect_devel
ll_ssl
ll_ssl_justconnect
ll_ssl_justlogin
ll_ssl_justconnect_sslargs
ll_tls_justconnect
ll_tls_justlogin
ll_tls
ll_tls_justlogin_sslargs_failure_EXIT_TLS_FAILURE
ll_authmech_PLAIN
ll_authmech_xoauth2_gmail
ll_authmech_xoauth2_json_gmail
ll_authmech_LOGIN
ll_authmech_CRAMMD5
ll_authmech_PREAUTH
ll_authmech_NTLM
ll_authmech_NTLM_domain
ll_authmech_NTLM_trylogin_ok
ll_authmech_NTLM_trylogin_fail
ll_authuser
ll_proxyauth_missing_authuser
ll_proxyauth_authuser
ll_delete1_delete2
ll_delete2
ll_delete1
ll_delete1_twoemails
ll_folderrec
ll_memory_consumption
ll_newmessage
ll_usecache
ll_usecache_noheader
ll_usecache_debugcache
ll_nousecache
ll_delete2foldersonly_NEW_3
ll_delete2foldersonly_dry
ll_delete2foldersonly_subfolder2
ll_delete2foldersbutnot
ll_folder_create
ll_folder_create_INBOX_Inbox
ll_delete2folders
ll_useuid
ll_useuid_nousecache
ll_noheader_force
ll_noheader
ll_domino1_domino2
ll_domino2
ll_with_flags_errors
ll_errorsmax
ll_exitwhenover
ll_exitwhenover_noerrorsdump
fuzz_basic
fuzz_network
testslive
testslive6
ll_abort_pidfile_no_exist
ll_abort_noprocess
ll_abort_not_a_pid_number
ll_abort_basic
ll_abort_cgi_context_tail
ll_abort_no_pidfile_option
ll_abort_byfile_hand_made
ll_abort_byfile_imapsync_made
ll_abort_byfile_normal_run
ll_sigreconnect_INT
ll_diff_log_stdout_debugssl
curl_online_args
curl_online_file
ksks_reset_test1
memory_stress
'

# 2019_12 Removed
# ks_justconnect_ipv6_nossl
# ks_justconnect_ipv6


other_tests='
archiveopteryx_1
msw
msw2
ll_bigmail
ll_justlogin_backslash_char
'

l() {
	echo "$mandatory_tests" "$other_tests"
}

# minimal and fatal tests

run_tests perl_syntax || exit 1

set_return_code_variables

if test $# -eq 0; then
        # mandatory tests
        if run_tests $mandatory_tests; then
                ./imapsync --version >> .tests_passed
                return 0
        fi
else
        # selective tests
        run_tests "$@"
        return $?
fi

