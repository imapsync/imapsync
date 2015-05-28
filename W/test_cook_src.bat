REM $Id: test_exe.bat,v 1.11 2014/05/22 10:13:34 gilles Exp gilles $

cd /D %~dp0

@REM EXIT

perl .\imapsync
perl .\imapsync --tests 
perl .\imapsync --testslive

@PAUSE