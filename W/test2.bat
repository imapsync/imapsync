
@REM $Id: test2.bat,v 1.22 2018/09/04 03:40:16 gilles Exp gilles $
@REM

cd /D %~dp0

@REM @ECHO off

@REM perl .\imapsync --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justfoldersizes | findstr /C:"Host2 Total size:"

@REM findstr /l /C:"Error login" LOG_imapsync\*.txt

@REM perl .\imapsync --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justlogin 

perl -e "print join(' ', keys(%%SIG))"
echo
