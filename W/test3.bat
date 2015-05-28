
@REM $Id: test3.bat,v 1.19 2015/03/15 03:02:58 gilles Exp gilles $
cd /D %~dp0

@REM \$1 must be $1 on Windows
@REM .\imapsync.exe  --host1 ex-cashub1.caltech.edu --justconnect --host2 ex-cashub1.caltech.edu --ssl1 --ssl2 --ssl1_SSL_version SSLv3 --ssl2_SSL_version SSLv3  

@REM perl .\imapsync --tests_debug

@REM @EXIT

@REM perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
@REM  --nofoldersizes --regextrans2 "s,INBOX\\yop\\(.*),OLDBOX\\$1," --prefix1 "" --sep1 "." --sep2 "\\" --prefix2 "" --justfolders --dry --debug

.\imapsync.exe ^
        --host1 p --user1 tata ^
        --passfile1 secret.tata ^
        --host2 imap-mail.outlook.com --ssl2 --user2 gilles.lamiral@outlook.com ^
        --passfile2 secret.outlook.com ^
        --folder INBOX  --usecache --regextrans2 "s/INBOX/tata/" 


@EXIT




