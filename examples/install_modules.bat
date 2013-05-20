
REM $Id: install_modules.bat,v 1.2 2013/05/06 08:26:39 gilles Exp gilles $
REM hi 

ECHO Installing Perl modules for imapsync
CD C:\msys\1.0\home\Admin\imapsync

perl -mMail::IMAPClient -e ""
IF ERRORLEVEL 0 GOTO install_01
perl -MCPAN -e "install Mail::IMAPClient"

:install_01

FOR %%M in ( Mail::IMAPClient ^
             IO::Socket IO::Socket::SSL ^
             Digest::MD5 Digest::HMAC_MD5 ^
             Term::ReadKey File::Spec ^
             Time::HiRes ^
             Data::Uniqid URI::Escape ^
             Authen::NTLM ^
             Time::Local ^
             PAR::Packer ) DO ECHO Testing %%M ^
   & perl -m%%M -e "" || perl -MCPAN -e "install %%M"


ECHO Perl modules for imapsync installed

PAUSE


