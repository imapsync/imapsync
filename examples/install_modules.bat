
REM $Id: install_modules.bat,v 1.8 2013/09/19 10:34:33 gilles Exp gilles $

@ECHO OFF 

ECHO Installing Perl modules for imapsync
REM CD /D %~dp0

perl -v
IF ERRORLEVEL 1 ECHO Perl needed. Install Strawberry Perl. Get it at http://strawberryperl.com/ ^
  && EXIT /B

REM perl is there

FOR %%M in ( Test::Pod ^
             IO::Socket::INET IO::Socket::INET6 IO::Socket::IP ^
             Net::SSLeay ^
             Crypt::SSLeay Net::SSL IO::Socket::SSL ^
             Digest::MD5 Digest::HMAC_MD5 ^
             Term::ReadKey File::Spec ^
             Time::HiRes ^
             Data::Uniqid URI::Escape ^
             Authen::NTLM ^
             Time::Local ^
             Mail::IMAPClient ^
             Getopt::ArgvFile Module::ScanDeps ^
             PAR::Packer ) DO ECHO Updating %%M ^
   & perl -MCPAN -e "install %%M"

REM   & perl -m%%M -e "" || perl -MCPAN -e "install %%M"


ECHO Perl modules for imapsync installed
REM PAUSE


