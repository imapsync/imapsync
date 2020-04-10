@REM

@REM $Id: test_exe_2.bat,v 1.13 2018/04/24 00:13:55 gilles Exp gilles $

@REM cd C:\msys\1.0\home\Admin\imapsync
cd /D %~dp0

@REM   imapsync.exe --host1 p --user1 toto --passfile1 secret.toto --host2 p --user2 titi --passfile2 secret.titi
@REM .\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi

@REM .\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
@REM   --foldersizes --usecache --folder "INBOX.[bracket]" --debugcache

@REM .\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
@REM    --dry --nofoldersizes --regextrans2 "s,(.*),\L$1," --justfolders

@REM .\imapsync.exe --testslive
@REM perl .\imapsync --tests

@REM .\imapsync.exe --testslive --authmech2 XOAUTH2 

@REM .\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com --passfile2 secret.gilles_gmail --authmech2 XOAUTH2 

@REM should fail 
@REM .\imapsync.exe  --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
@REM                 --folder """INBOX.blanc middle""" --f1f2 """INBOX.blanc middle=INBOX.blanc middle""" --dry
@REM PAUSE
@REM should work
@REM .\imapsync.exe --host1 p --user1 tete@est.belle --passfile1 secret.tete  --host2 p --user2 titi --passfile2 secret.titi ^
@REM                --folder "INBOX.blanc middle" --f1f2 "INBOX.blanc middle=INBOX.blanc middle" --dry

.\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi ^
                --folder "INBOX.Junk.2010" --dry


                      
.\imapsync.exe --simulong 300  --testslive                  
                      
                      
PAUSE

