
@REM $Id: install_module_one.bat,v 1.7 2019/02/11 00:09:32 gilles Exp gilles $

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
              IO::Socket::SSL Net::SSLeay PAR::Packer ^         
             ) DO perl -m%%M -e "print qq{Updating %%M $%%M::VERSION \n}" ^
   & ECHO cpanm --force %%M

REM IO::Socket::SSL Net::SSLeay PAR::Packer

@ECHO Perl modules for imapsync installed
PAUSE

EXIT /B

@ENDLOCAL
