
@REM $Id: test3.bat,v 1.16 2014/11/14 17:09:50 gilles Exp gilles $
cd /D %~dp0

@REM \$1 must be $1 on Windows
@REM .\imapsync.exe  --host1 ex-cashub1.caltech.edu --justconnect --host2 ex-cashub1.caltech.edu --ssl1 --ssl2 --ssl1_SSL_version SSLv3 --ssl2_SSL_version SSLv3  

perl .\imapsync --tests_debug

@REM @EXIT
perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
  --foldersizes --usecache --folder "INBOX.[bracket]" --debugcache

@EXIT




