@REM

@REM $Id: test_exe_2.bat,v 1.6 2015/03/20 03:11:22 gilles Exp gilles $

@REM cd C:\msys\1.0\home\Admin\imapsync
cd /D %~dp0

perl .\imapsync --tests

@REM @PAUSE