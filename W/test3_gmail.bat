
REM $Id: test3_gmail.bat,v 1.1 2013/07/23 13:29:56 gilles Exp gilles $

cd /D %~dp0

REM ./imapsync.exe --modules_version

perl .\imapsync --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com --passfile1 secret.gilles_gmail ^
                --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com --passfile2 secret.gilles_gmail ^
                --folder INBOX --dry

PAUSE

.\imapsync.exe --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com --passfile1 secret.gilles_gmail ^
               --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com --passfile2 secret.gilles_gmail ^
               --folder INBOX --dry
