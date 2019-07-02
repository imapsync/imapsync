
@REM $Id: install_module_one.bat,v 1.9 2019/05/28 13:20:08 gilles Exp gilles $

@SETLOCAL
@ECHO OFF 
@ECHO Currently running through %0 %*
SET SHELL=
SET
REM EXIT

CD /D %~dp0

perl -v
IF ERRORLEVEL 1 ECHO Perl needed. Install Strawberry Perl. Get it at http://strawberryperl.com/ ^
   && EXIT /B

@ECHO perl is here
@REM PAUSE
@REM EXIT
FOR %%M in ( 
              Crypt::OpenSSL::RSA ^         
             ) DO perl -m%%M -e "print qq{Updating %%M $%%M::VERSION \n}" ^
   & cpanm --force %%M

REM IO::Socket::SSL Net::SSLeay PAR::Packer IO::Tee Crypt::OpenSSL::RSA

@ECHO Perl modules for imapsync installed
@REM Do a PAUSE if run by double-click, aka, explorer (then ). No PAUSE in a DOS window or via ssh.
IF %0 EQU "%~dpnx0" IF "%SSH_CLIENT%"=="" PAUSE
EXIT /B

@ENDLOCAL
