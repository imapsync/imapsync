
REM $Id: install_modules.bat,v 1.15 2015/03/03 11:23:12 gilles Exp gilles $

@ECHO OFF 

ECHO Installing Perl modules for imapsync
REM CD /D %~dp0

perl -v
IF ERRORLEVEL 1 ECHO Perl needed. Install Strawberry Perl. Get it at http://strawberryperl.com/ ^
  && EXIT /B

REM perl is there

FOR %%M in ( ^
             Authen::NTLM ^
             Crypt::SSLeay ^
             Data::Uniqid ^
             Digest::HMAC_MD5 ^
             Digest::HMAC_SHA1 ^
             Digest::MD5 ^
             File::Copy::Recursive ^
             Getopt::ArgvFile ^
             IO::Socket::INET ^
             IO::Socket::INET6 ^
             IO::Socket::SSL ^
             IO::Tee ^
             Mail::IMAPClient ^
             Module::ScanDeps ^
             Net::SSL ^
             Net::SSLeay ^
             PAR::Packer ^
             Test::Pod ^
             Unicode::String ^
             URI::Escape ^
             ) DO ECHO Updating %%M ^
   & perl -MCPAN -e "install %%M"

REM   & perl -m%%M -e "" || perl -MCPAN -e "install %%M"

ECHO Perl modules for imapsync installed
REM PAUSE


