
@REM $Id: test_xoauth2.bat,v 1.1 2015/12/26 02:11:27 gilles Exp gilles $
@REM

cd /D %~dp0

@REM @ECHO off
@REM .\imapsync.exe --modules_version
@REM @PAUSE
@REM .\imapsync.exe --tests
@REM @PAUSE
@REM .\imapsync.exe --testslive
@REM @PAUSE

@REM SET PERL_LWP_ENV_PROXY=1
SET https_proxy=connect://localhost:3128/
ECHO %https_proxy%

@REM EXIT

perl .\imapsync --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com --passfile1 secret.xoauth2  --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com  --passfile2 secret.xoauth2 --justfoldersizes --nofoldersizes --authmech1 XOAUTH2 --authmech2 XOAUTH2 --debug 

