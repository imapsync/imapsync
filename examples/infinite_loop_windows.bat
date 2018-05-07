
@REM $Id: infinite_loop_windows.bat,v 1.3 2017/11/12 23:59:10 gilles Exp gilles $

@REM An infinite loop with a sleep of 3600 seconds between each run

@REM First let's go in the directory this batch is
CD /D %~dp0

@REM How many seconds to sleep at each run inside the loop is set in the variable %sleep%
@REM If TIMEOUT command is not available then the sleep is done with a ping command.
SET sleep=3600

:loop
  @ECHO Hi
  .\imapsync.exe --host1 test1.lamiral.info  --user1 test1 --password1  "secret1"  ^
                 --host2 test2.lamiral.info  --user2 test2 --password2  "secret2"  ^
                 --automap --justfolders --dry 
  TIMEOUT /T %sleep% || ping 127.0.0.1 -n %sleep%

GOTO loop

