
REM $Id: build_exe.bat,v 1.23 2014/11/14 17:05:08 gilles Exp gilles $
@ECHO OFF

ECHO Building imapsync.exe

cd /D %~dp0

CALL .\examples\install_modules.bat

perl -mMail::IMAPClient ^
     -mIO::Socket  -mIO::Socket::IP   -mIO::Socket::SSL  -mIO::Socket::INET ^
     -mDigest::MD5 -mDigest::HMAC_MD5 -mDigest::HMAC_SHA1 ^
     -mTerm::ReadKey  -mFile::Spec -mAuthen::NTLM ^
     -mTime::Local -mURI::Escape -mData::Uniqid ^
     -mFile::Copy::Recursive  ^
     -mIO::Tee ^
     -mUnicode::String ^
     -e ''

cd
@ECHO ON
@REM --link libssl32_.dll 
pp -o imapsync.exe  ^
      --link libeay32_.dll ^
      --link zlib1_.dll --link ssleay32_.dll ^
      -M Mail::IMAPClient ^
      -M IO::Socket -M IO::Socket::IP -M IO::Socket::SSL -M IO::Socket::INET ^
      -M Digest::MD5 -M Digest::HMAC_MD5 -M Digest::HMAC_SHA1 ^
      -M Term::ReadKey -M File::Spec -M Authen::NTLM ^
      -M Time::Local -M URI::Escape -M Data::Uniqid ^
      -M File::Copy::Recursive ^
      -M IO::Tee ^
      -M Unicode::String ^
      imapsync

echo Done building imapsync.exe 

