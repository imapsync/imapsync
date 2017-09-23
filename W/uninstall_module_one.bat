
@REM $Id: uninstall_module_one.bat,v 1.1 2017/07/08 00:10:46 gilles Exp gilles $

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
              Net::Ping ^         
             ) DO perl -m%%M -e "print qq{Uninstalling %%M $%%M::VERSION \n}" ^
   & cpanm --uninstall %%M

REM IO::Socket::SSL Net::SSLeay PAR::Packer

@ECHO Perl modules for imapsync installed
PAUSE


