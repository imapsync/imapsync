@REM

@REM $Id: test_tests.bat,v 1.2 2015/06/27 20:01:16 gilles Exp gilles $

@REM cd C:\msys\1.0\home\Admin\imapsync
cd /D %~dp0

perl .\imapsync --modules_version 
perl .\imapsync --tests

@REM @PAUSE
