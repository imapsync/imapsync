
@REM $Id: install_module_ssl.bat,v 1.2 2015/12/14 15:15:25 gilles Exp gilles $

@ECHO OFF 
SET SHELL=
SET
REM EXIT

ECHO Installing Perl module IO::Socket::SSL for imapsync
REM CD /D %~dp0

perl -v
IF ERRORLEVEL 1 ECHO Perl needed. Install Strawberry Perl. Get it at http://strawberryperl.com/ ^
  && EXIT /B

@ECHO perl is here

FOR %%M in ( 
              IO::Socket::SSL ^         
             ) DO perl -m%%M -e "print qq{Updating %%M $%%M::VERSION \n}" ^
   & cpanm --force %%M

REM IO::Socket::SSL

@ECHO Perl modules for imapsync installed
PAUSE


