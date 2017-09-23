@REM $Id: test_exe_tests.bat,v 1.2 2017/05/02 08:43:02 gilles Exp gilles $

@SETLOCAL
@ECHO OFF

ECHO Currently running through %0 %*

CD /D %~dp0

REM Remove the error file because its existence means an error occured during this script execution
IF EXIST LOG_bat\%~nx0.txt DEL LOG_bat\%~nx0.txt

REM CALL :handle_error .\imapsync.exe --testsunit tests_always_fail
CALL :handle_error .\imapsync.exe --tests

@REM @PAUSE
@ENDLOCAL
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

