@REM

@REM $Id: test_exe_2.bat,v 1.10 2016/07/20 12:48:28 gilles Exp gilles $

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

@REM .\imapsync.exe  --host1 mail2.name-services.com  --user1 jessica@champlaindoor.com --passfile1 secret.mail2World --host2 mail.emailsrvr.com  --user2 jessica@champlaindoor.com --passfile2 secret.mail2World --sep1 / --prefix1 "" --noabletosearch --fetch_hash_set "1:*" --delete2duplicates

