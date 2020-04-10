
@REM $Id: test2.bat,v 1.23 2019/03/22 18:10:31 gilles Exp gilles $
@REM

cd /D %~dp0

@REM @ECHO off

@REM perl .\imapsync --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justfoldersizes | findstr /C:"Host2 Total size:"

@REM findstr /l /C:"Error login" LOG_imapsync\*.txt

@REM perl .\imapsync --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justlogin 

@REM perl -e "print join(' ', keys(%%SIG))"

@ECHO ==== \Seen set in case unset
perl ./imapsync --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 tata --passfile2 secret.tata ^
 --nofoldersizes --no-modulesversion  --folder INBOX.flagsetSeen --debugflags --dry --regexflag "s,\\Seen,," --regexflag "s,,\\Seen ,"
 
@REM --regexflag "s,^((?!\\Seen).*)$,$1 \\Seen,"


