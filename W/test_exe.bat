REM $Id: test_exe.bat,v 1.19 2017/08/31 01:57:33 gilles Exp gilles $

@SETLOCAL
@ECHO OFF
ECHO Currently running through %0 %*

cd /D %~dp0

@REM Remove the error file because its existence means an error occured during this script execution
IF EXIST LOG_bat\%~nx0.txt DEL LOG_bat\%~nx0.txt
@REM CALL :handle_error  .\imapsync.exe --thisoptionnoexists
@REM CALL :handle_error  perl imapsync  --tests
CALL :handle_error  .\imapsync.exe --tests
CALL :handle_error  .\imapsync.exe --testslive  --nossl2
@REM CALL :handle_error  .\imapsync.exe --testslive6 --nossl2

EXIT /B

@ECHO ==== All 8 combinaisons between ssl1/tls1 ssl2/tls2 justconnect/justlogin
CALL :handle_error CALL :launch_imapsync --justconnect --ssl1 --ssl2 
CALL :handle_error CALL :launch_imapsync --justconnect --tls1 --tls2 
CALL :handle_error CALL :launch_imapsync --justconnect --ssl1 --tls2 
CALL :handle_error CALL :launch_imapsync --justconnect --tls1 --ssl2 
CALL :handle_error CALL :launch_imapsync --justlogin   --ssl1 --ssl2 
CALL :handle_error CALL :launch_imapsync --justlogin   --tls1 --tls2 
CALL :handle_error CALL :launch_imapsync --justlogin   --ssl1 --tls2 
CALL :handle_error CALL :launch_imapsync --justlogin   --tls1 --ssl2 
@ECHO ==== various calls
CALL :handle_error CALL :launch_imapsync --ssl1 --ssl1_SSL_version SSLv3 --ssl2 --justconnect 
CALL :handle_error CALL :launch_imapsync --ssl1 --ssl1_SSL_version SSLv3 --ssl2 --justlogin 
CALL :handle_error CALL :launch_imapsync --ssl1 --ssl2 --delete2  
CALL :handle_error CALL :launch_imapsync --ssl1 --ssl2 --delete2 --folder INBOX 
CALL :handle_error CALL :launch_imapsync --ssl1 --ssl2 --delete2 --folder INBOX --usecache

ENDLOCAL
EXIT /B


:handle_error
SETLOCAL
ECHO IN %0 %*
%*
SET CMD_RETURN=%ERRORLEVEL%
ECHO CMD_RETURN=%CMD_RETURN%
IF %CMD_RETURN% EQU 0 (
        ECHO GOOD END
) ELSE (
        ECHO BAD END
        IF NOT EXIST LOG_bat MKDIR LOG_bat
        ECHO Failure calling %* >> LOG_bat\%~nx0.txt
)
ENDLOCAL
EXIT /B


:launch_imapsync
@SETLOCAL
ECHO IN %0 %*
.\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi %*
@ENDLOCAL
@EXIT /B

