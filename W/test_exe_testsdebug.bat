@REM $Id: test_exe_testsdebug.bat,v 1.2 2019/05/28 13:20:08 gilles Exp gilles $

@SETLOCAL
@ECHO OFF

ECHO Currently running through %0 %*

CD /D %~dp0

REM Remove the error file because its existence means an error occured during this script execution
IF EXIST LOG_bat\%~nx0.txt DEL LOG_bat\%~nx0.txt

REM CALL :handle_error .\imapsync.exe --testsunit tests_always_fail
CALL :handle_error .\imapsync.exe --testsdebug --debug

@REM @PAUSE
@ENDLOCAL
@REM Do a PAUSE if run by double-click, aka, explorer (then ). No PAUSE in a DOS window or via ssh.
IF %0 EQU "%~dpnx0" IF "%SSH_CLIENT%"=="" PAUSE
@EXIT /B


:handle_error
SETLOCAL
ECHO IN %0 with parameters %*
%*
SET CMD_RETURN=%ERRORLEVEL%

IF %CMD_RETURN% EQU 0 (
        ECHO GOOD END
) ELSE (
        ECHO BAD END
        IF NOT EXIST LOG_bat MKDIR LOG_bat
        ECHO Failure running %* >> LOG_bat\%~nx0.txt
)
ENDLOCAL
EXIT /B

