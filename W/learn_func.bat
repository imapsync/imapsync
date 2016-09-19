REM $Id: learn_func.bat,v 1.2 2016/06/28 11:39:42 gilles Exp gilles $

@SETLOCAL
@ECHO OFF

ECHO Currently running through %0 %*

CD /D %~dp0

REM Remove the error file because its existence means an error occured during this script execution
IF EXIST LOG_bat\%~nx0.txt DEL LOG_bat\%~nx0.txt

CALL :handle_error EXIT /B 1  
CALL :handle_error EXIT /B 0 
CALL :handle_error NOEXIST
CALL :handle_error ECHO "STILL THERE? FIRST" 
CALL :handle_error EXIT 0 
CALL :handle_error ECHO "STILL THERE? SECOND" 
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

