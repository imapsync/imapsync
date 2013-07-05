
REM $Id: install_modules.bat,v 1.5 2013/07/03 12:00:23 gilles Exp gilles $

@ECHO OFF 

ECHO Installing Perl modules for imapsync
REM CD /D %~dp0

perl -v
IF ERRORLEVEL 1 ECHO Perl needed. Install Strawberry Perl. Get it at http://strawberryperl.com/ ^
  && EXIT /B

REM perl is there

FOR %%M in ( IO::Socket ^
             Net::SSLeay IO::Socket::SSL ^
             Digest::MD5 Digest::HMAC_MD5 ^
             Term::ReadKey File::Spec ^
             Time::HiRes ^
             Data::Uniqid URI::Escape ^
             Authen::NTLM ^
             Time::Local ^
             Mail::IMAPClient ^
             PAR::Packer ) DO ECHO Testing %%M ^
   & perl -m%%M -e "" || perl -MCPAN -e "install %%M"


ECHO Perl modules for imapsync installed
REM PAUSE


