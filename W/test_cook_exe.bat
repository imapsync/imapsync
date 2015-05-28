REM $Id: test_exe.bat,v 1.11 2014/05/22 10:13:34 gilles Exp gilles $

cd /D %~dp0

@REM EXIT

.\imapsync.exe
.\imapsync.exe --tests 
.\imapsync.exe --testslive

@PAUSE