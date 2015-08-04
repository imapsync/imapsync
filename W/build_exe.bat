
REM $Id: build_exe.bat,v 1.28 2015/05/11 01:09:57 gilles Exp gilles $
@ECHO OFF

ECHO Building imapsync.exe

@REM Allow to be called from anywhere; 
@REM the following command cd to dirname of the current batch pathname
cd /D %~dp0

CALL .\install_modules.bat

perl ^
     -mAuthen::NTLM ^
     -mData::Dumper ^
     -mData::Uniqid ^
     -mDigest::HMAC_MD5 ^
     -mDigest::HMAC_SHA1 ^
     -mDigest::MD5 ^
     -mFile::Copy::Recursive  ^
     -mFile::Spec ^
     -mIO::Socket ^
     -mIO::Socket::INET ^
     -mIO::Socket::IP ^
     -mIO::Socket::SSL ^
     -mIO::Tee ^
     -mMail::IMAPClient ^
     -mTerm::ReadKey ^
     -mTime::Local ^
     -mUnicode::String ^
     -mURI::Escape ^
     -mJSON::WebToken ^
     -mLWP::UserAgent ^
     -mHTML::Entities ^
     -mJSON ^
     -e ''

cd
@ECHO ON
@REM --link libssl32_.dll 
pp -o imapsync.exe  ^
      --link libeay32_.dll ^
      --link zlib1_.dll ^
      --link ssleay32_.dll ^
      -M Mail::IMAPClient ^
      -M IO::Socket ^
      -M IO::Socket::IP ^
      -M IO::Socket::SSL ^
      -M IO::Socket::INET ^
      -M Digest::MD5 ^
      -M Digest::HMAC_MD5 ^
      -M Digest::HMAC_SHA1 ^
      -M Term::ReadKey ^
      -M File::Spec ^
      -M Authen::NTLM ^
      -M Time::Local ^
      -M URI::Escape ^
      -M Data::Uniqid ^
      -M File::Copy::Recursive ^
      -M IO::Tee ^
      -M Unicode::String ^
      -M JSON::WebToken ^
      -M LWP::UserAgent ^
      -M HTML::Entities ^
      -M JSON ^
      .\imapsync

echo Done building imapsync.exe 

