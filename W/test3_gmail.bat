
@REM $Id: test3_gmail.bat,v 1.2 2014/11/14 17:09:34 gilles Exp gilles $

cd /D %~dp0

@REM ./imapsync.exe --modules_version

@REM perl .\imapsync --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com --passfile1 secret.gilles_gmail ^
@REM                 --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com --passfile2 secret.gilles_gmail ^
@REM                 --folder INBOX --dry

@REM PAUSE

.\imapsync.exe --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com --passfile1 secret.gilles_gmail ^
               --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com --passfile2 secret.gilles_gmail ^
               --usecache --nofoldersizes 
