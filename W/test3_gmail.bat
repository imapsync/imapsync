
@REM $Id: test3_gmail.bat,v 1.5 2016/08/19 18:27:13 gilles Exp gilles $

cd /D %~dp0

@REM ./imapsync.exe --justbanner

@REM perl .\imapsync --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com --passfile1 secret.gilles_gmail ^
@REM                 --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com --passfile2 secret.gilles_gmail ^
@REM                 --folder INBOX --dry

@REM PAUSE

perl .\imapsync --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com --passfile1 secret.gilles_gmail ^
                --host2 p --user2 tata --passfile2 secret.tata ^
                --regextrans2 "s,\[Gmail\].,," --dry --justfolders
