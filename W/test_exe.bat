REM $Id: test_exe.bat,v 1.22 2019/05/28 13:20:08 gilles Exp gilles $

@SETLOCAL
@ECHO OFF
ECHO Currently running through %0 %*

cd /D %~dp0

@REM Remove the error file because its existence means an error occurred during this script execution
IF EXIST LOG_bat\%~nx0.txt DEL LOG_bat\%~nx0.txt

CALL :handle_bad_success  .\imapsync.exe --thisoptionnoexists 

CALL :handle_error  .\imapsync.exe --tests
CALL :handle_error  .\imapsync.exe --testslive  --nossl2
CALL :handle_bad_success  CALL :launch_imapsync --folder """INBOX.blanc middle""" --f1f2 """INBOX.blanc middle=INBOX.blanc middle""" --dry
CALL :handle_error  CALL :launch_imapsync --folder "INBOX.blanc middle"     --f1f2 "INBOX.blanc middle=INBOX.blanc middle"     --dry

@REM CALL :handle_error  .\imapsync.exe --testslive6 --nossl2

@REM EXIT /B

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
CALL :handle_error CALL :launch_imapsync --ssl1 --ssl1_SSL_version SSLv23 --justconnect 
CALL :handle_error CALL :launch_imapsync --ssl1 --sslargs1 SSL_version=SSLv23 --sslargs1 SSL_verify_mode=0 --justlogin
CALL :handle_error CALL :launch_imapsync --ssl1 --ssl1_SSL_version SSLv23 --justconnect 
CALL :handle_error CALL :launch_imapsync --ssl1 --sslargs1 SSL_version=SSLv23 --sslargs1 SSL_verify_mode=0 --justlogin 

CALL :handle_error CALL :launch_imapsync --ssl1 --ssl2 --delete2  
CALL :handle_error CALL :launch_imapsync --ssl1 --ssl2 --delete2 --folder INBOX 
CALL :handle_error CALL :launch_imapsync --ssl1 --ssl2 --delete2 --folder INBOX --usecache

ENDLOCAL
@REM Do a PAUSE if run by double-click, aka, explorer (then ). No PAUSE in a DOS window or via ssh.
IF %0 EQU "%~dpnx0" IF "%SSH_CLIENT%"=="" PAUSE
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

:handle_bad_success
SETLOCAL
ECHO IN %0 %*
%*
SET CMD_RETURN=%ERRORLEVEL%
ECHO CMD_RETURN=%CMD_RETURN%
IF %CMD_RETURN% NEQ 0 (
        ECHO GOOD BAD END
) ELSE (
        ECHO BAD GOOD END
        IF NOT EXIST LOG_bat MKDIR LOG_bat
        ECHO No failure calling %* >> LOG_bat\%~nx0.txt
)
ENDLOCAL
EXIT /B


:launch_imapsync
@SETLOCAL
ECHO IN %0 %*
.\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi %*
@ENDLOCAL
@EXIT /B

