
@REM $Id: install_module_one.bat,v 1.4 2016/07/20 21:44:40 gilles Exp gilles $

@ECHO OFF 
SET SHELL=
SET
REM EXIT

REM CD /D %~dp0

perl -v
IF ERRORLEVEL 1 ECHO Perl needed. Install Strawberry Perl. Get it at http://strawberryperl.com/ ^
  && EXIT /B

@ECHO perl is here

FOR %%M in ( 
              IO::Socket::SSL Net::SSLeay PAR::Packer^         
             ) DO perl -m%%M -e "print qq{Updating %%M $%%M::VERSION \n}" ^
   & cpanm --force %%M

REM IO::Socket::SSL

@ECHO Perl modules for imapsync installed
PAUSE


