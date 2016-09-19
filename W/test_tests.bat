@REM $Id: test_tests.bat,v 1.5 2016/08/19 14:08:01 gilles Exp gilles $

@SETLOCAL
@ECHO OFF

ECHO Currently running through %0 %*

CD /D %~dp0

REM Remove the error file because its existence means an error occured during this script execution
IF EXIST LOG_bat\%~nx0.txt DEL LOG_bat\%~nx0.txt

CALL :handle_error perl .\imapsync --justbanner
CALL :handle_error perl .\imapsync --testsdebug
CALL :handle_error perl .\imapsync --tests

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

