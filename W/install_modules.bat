REM $Id: install_modules.bat,v 1.37 2019/05/28 13:20:08 gilles Exp gilles $

::------------------------------------------------------
::--------------- Main of install_modules.bat ----------
@SETLOCAL
@ECHO OFF
ECHO Currently running through %0 %*

@REM Needed with remote ssh
SET SHELL=
SET
ECHO Installing Perl modules for imapsync

CD /D %~dp0

CALL :handle_error CALL :detect_perl
CALL :handle_error CALL :update_modules

@ENDLOCAL
@REM Do a PAUSE if run by double-click, aka, explorer (then ). No PAUSE in a DOS window or via ssh.
IF %0 EQU "%~dpnx0" IF "%SSH_CLIENT%"=="" PAUSE
EXIT /B


::------------------------------------------------------


::------------------------------------------------------
::--------------- Detect Perl --------------------------
:detect_perl
@SETLOCAL
perl -v
IF ERRORLEVEL 1 ECHO Perl needed. Install Strawberry Perl. Get it at http://strawberryperl.com/ ^
  && PAUSE && EXIT 3
ECHO perl is there
@ENDLOCAL
EXIT /B
::------------------------------------------------------


::------------------------------------------------------
::---------------- Update modules ----------------------
:update_modules
@SETLOCAL
FOR %%M in ( ^
 File::Tail ^
 Regexp::Common ^
 Sys::MemInfo ^
 Test::MockObject ^
 Readonly ^
 Authen::NTLM ^
 Crypt::SSLeay ^
 Data::Uniqid ^
 Digest::HMAC_MD5 ^
 Digest::HMAC_SHA1 ^
 Digest::MD5 ^
 File::Copy::Recursive ^
 Getopt::ArgvFile ^
 Socket6 ^
 Net::SSLeay ^
 IO::Socket::INET ^
 IO::Socket::INET6 ^
 IO::Socket::SSL ^
 IO::Tee ^
 Mail::IMAPClient ^
 Module::ScanDeps ^
 Net::SSL ^
 PAR::Packer ^
 Pod::Usage ^
 Test::Pod ^
 Unicode::String ^
 URI::Escape ^
 Crypt::OpenSSL::RSA ^
 JSON ^
 JSON::WebToken ^
 LWP ^
 HTML::Entities ^
 Encode::Byte ^
 ) DO @perl -m%%M -e "print qq{Updating %%M $%%M::VERSION \n}" ^
   & cpanm %%M

ECHO Perl modules for imapsync updated
REM PAUSE
@REM @ECHO Net::SSLeay not updated

@ENDLOCAL
EXIT /B


::------------------------------------------------------


::------------------------------------------------------
::----------- Handle errors in LOG_bat\ directory ------
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
        ECHO Failure calling with extra %* >> LOG_bat\%~nx0.txt
)
ENDLOCAL
EXIT /B
::------------------------------------------------------

