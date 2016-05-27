
REM $Id: install_modules.bat,v 1.22 2015/12/26 02:10:15 gilles Exp gilles $

@ECHO OFF
@REM Needed with remote ssh
SET SHELL=
SET
ECHO Installing Perl modules for imapsync

CD /D %~dp0

perl -v
IF ERRORLEVEL 1 ECHO Perl needed. Install Strawberry Perl. Get it at http://strawberryperl.com/ ^
  && PAUSE && EXIT /B 3

ECHO perl is there

FOR %%M in ( ^
 Filesys::DfPortable ^
 Authen::NTLM ^
 Crypt::SSLeay ^
 Data::Uniqid ^
 Digest::HMAC_MD5 ^
 Digest::HMAC_SHA1 ^
 Digest::MD5 ^
 File::Copy::Recursive ^
 Getopt::ArgvFile ^
 Socket6 ^
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


