@REM

@REM $Id: test_exe_2.bat,v 1.6 2015/03/20 03:11:22 gilles Exp gilles $

@REM cd C:\msys\1.0\home\Admin\imapsync
cd /D %~dp0

@REM   imapsync.exe --host1 p --user1 toto --passfile1 secret.toto --host2 p --user2 titi --passfile2 secret.titi
@REM .\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi

@REM .\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
@REM   --foldersizes --usecache --folder "INBOX.[bracket]" --debugcache

@REM .\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi ^
@REM    --dry --nofoldersizes --regextrans2 "s,(.*),\L$1," --justfolders

@REM .\imapsync.exe --testslive
perl .\imapsync --tests
