REM $Id: test_cook_src.bat,v 1.3 2017/09/07 00:59:26 gilles Exp gilles $

cd /D %~dp0



perl .\imapsync
@PAUSE 
perl .\imapsync --tests 
@PAUSE 
perl .\imapsync --testslive
@PAUSE 
perl .\imapsync --testslive6
@ECHO Tests for imapsync script are finished, bye!
@PAUSE