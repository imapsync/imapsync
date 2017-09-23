REM $Id: test_cook_exe.bat,v 1.4 2017/09/07 00:59:35 gilles Exp gilles $

cd /D %~dp0

.\imapsync.exe
@PAUSE 
.\imapsync.exe --tests 
@PAUSE 
.\imapsync.exe --testslive  --nossl2
@PAUSE 
.\imapsync.exe --testslive6 --nossl2
@ECHO The previous test fails with "Invalid argument" usually (August 2017)
@ECHO Tests ended, bye.
@PAUSE

@REM EXIT
