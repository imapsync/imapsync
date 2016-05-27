REM $Id: test_cook_exe.bat,v 1.1 2015/04/02 23:38:23 gilles Exp gilles $

cd /D %~dp0

@REM EXIT

.\imapsync.exe
.\imapsync.exe --tests 
.\imapsync.exe --testslive

@PAUSE