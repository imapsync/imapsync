
REM $Id: build_exe.bat,v 1.18 2013/07/23 11:27:50 gilles Exp gilles $
@ECHO OFF

ECHO Building imapsync.exe

CALL .\examples\install_modules.bat

cd /D %~dp0

perl -mMail::IMAPClient -mIO::Socket -mIO::Socket::SSL -mIO::Socket::IP ^
     -mDigest::MD5 -mDigest::HMAC_MD5 -mDigest::HMAC_SHA1 ^
     -mTerm::ReadKey  -mFile::Spec -mAuthen::NTLM ^
     -mTime::Local -mURI::Escape -mData::Uniqid ^
     -e ''

cd
@ECHO ON
pp -o imapsync.exe  ^
      --link libeay32_.dll --link libssl32_.dll ^
      --link zlib1_.dll --link ssleay32_.dll ^
      -M Mail::IMAPClient -M IO::Socket -M IO::Socket::IP -M IO::Socket::SSL -M IO::Socket::INET  ^
      -M Digest::MD5 -M Digest::HMAC_MD5 -M Digest::HMAC_SHA1 ^
      -M Term::ReadKey -M Authen::NTLM ^
      -M Time::Local -M URI::Escape -M Data::Uniqid ^
      imapsync

echo Done building imapsync.exe 
pause
