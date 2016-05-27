@REM $Id: test_tests.bat,v 1.3 2015/09/19 08:46:11 gilles Exp gilles $

@REM cd C:\msys\1.0\home\Admin\imapsync
cd /D %~dp0

perl .\imapsync --modules_version 
perl .\imapsync --tests

@REM @PAUSE
