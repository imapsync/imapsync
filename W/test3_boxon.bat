

cd /D %~dp0

REM perl imapsync --host1 p  --user1 toto --passfile1 secret.toto  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2  --folder INBOX 
REM .\imapsync.exe --host1 p  --user1 toto --passfile1 secret.toto  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2 --justconnect 
REM PAUSE

REM .\imapsync.exe --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2 --delete2 --folder INBOX 
REM .\imapsync.exe --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2 --delete2 --folder INBOX --usecache

@REM perl .\imapsync --tests_debug

@REM @EXIT

@REM perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
@REM  --nofoldersizes --regextrans2 "s,INBOX\\yop\\(.*),OLDBOX\\$1," --prefix1 "" --sep1 "." --sep2 "\\" --prefix2 "" --justfolders --dry --debug

@REM  .\imapsync.exe  --host1 p --user1 tata  --passfile1 secret.tata  --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com ^
@REM         --passfile2 secret.outlook.com  --folder INBOX  --usecache --regextrans2 "s/INBOX/tata/" 

@REM  Change all " to _
@REM --justfolders --nofoldersizes --dry --regextrans2 s,\^",_,g


@REM perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
@REM     --justfolders --nofoldersizes --dry  --regextrans2 "s,(/|^) +,$1,g" --regextrans2 "s, +(/|$),$1,g"

@ECHO ====  --subfolder2 SUB2
perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
     --justfolders  --subfolder2 SUB2 --dry 


@ECHO ==== 4 --TLS1 --TLS2 --JUSTLOGIN
perl ./imapsync --debug --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --justconnect


@ECHO ==== Remove [Gmail] on host2
perl .\imapsync --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com --passfile1 secret.gilles_gmail ^
                --host2 p --user2 tata --passfile2 secret.tata ^
                --regextrans2 "s,\[Gmail\].,," --dry --justfolders

@ECHO ====  --subfolder2 SUB2 domino
perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
     --sep2 "\\" --prefix2 "" --justfolders  --subfolder2 SUB2 --dry --debug --folder INBOX.yop.yap.yip

@ECHO ====  --subfolder2 remove INBOX domino
perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
     --prefix1 "" ^
     --sep2 "\\" --prefix2 ""  --regextrans2 "s,^Inbox\\(.*),$1,i"  --justfolders --dry --debug --folder INBOX.yop.yap.yip

@ECHO ==== split long lines 
perl ./imapsync ^
                --host1 p  --user1 tata ^
                --passfile1 secret.tata ^
                --host2 p  --user2 titi ^
                --passfile2 secret.titi ^
                --nofoldersizes  --folder "INBOX.longline" --regexmess "s,(.{9900}),$1\r\n,g" --dry --debugcontent

@ECHO ==== password within double-quotes via --passfile1
perl ./imapsync --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi ^
                --debugimap2 --debugcontent --folder INBOX --maxage 1

@ECHO ==== \Seen set in case unset
perl ./imapsync --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 tata --passfile2 secret.tata ^
 --nofoldersizes --no-modulesversion  --folder INBOX.flagsetSeen --debugflags --dry --regexflag "s,\\Seen,," --regexflag "s,,\\Seen ,"
		
@ECHO ==== password double-quotes within via --password1
@REM perl ./imapsync --host1 p  --user1 tata --password1 \"ami\\\"seen\"  --host2 p --user2 titi --passfile2 secret.titi --debugimap1 --showpasswords --justlogin
perl ./imapsync --host1 p  --user1 tata --password1 ami\\\"seen  --host2 p --user2 titi --passfile2 secret.titi --debugimap1 --showpasswords --justlogin

	
@ECHO ====  --justloadavg --justbanner

@REM perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi --justbanner


@REM perl -V
@REM perl -e "print 'zzz'"
@REM perl -c .\imapsync
@REM perl    .\imapsync --version
@REM --testsdebug --debugdev

@REM perl .\imapsync  --host1 imap.gmail.com   --host2 ks2ipv6.lamiral.info  --ssl1 --ssl2 --justconnect --debugimap
@REM perl .\imapsync  --host1 test.lamiral.info   --host2 ks2ipv6.lamiral.info  --nossl1 --justconnect --debugimap

@REM .\imapsync.exe  --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi --folder """INBOX.A B""" --justfolders
@REM perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi --folder "INBOX.A B" --justfolders

@REM Big emails
.\imapsync.exe --host1 p  --user1 big1 --passfile1 secret.big1 --host2 p --user2 big2 --passfile2 secret.big2 ^
               --folder INBOX.bigmail  --debugmemory --nofoldersizes 


@REM

