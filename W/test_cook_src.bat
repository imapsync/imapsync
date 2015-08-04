REM $Id: test_cook_src.bat,v 1.1 2015/04/02 23:38:16 gilles Exp gilles $

cd /D %~dp0

@REM EXIT

perl .\imapsync
perl .\imapsync --tests 
perl .\imapsync --testslive

@PAUSE