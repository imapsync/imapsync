
REM $Id: build_exe.bat,v 1.33 2015/11/23 16:47:21 gilles Exp gilles $
@ECHO OFF

ECHO Building imapsync.exe

@REM the following command cd to dirname of the current batch pathname
cd /D %~dp0

REM CALL .\install_modules.bat

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
     -mCrypt::OpenSSL::RSA ^
     -e ''

@ECHO ON
del imapsync.exe
pp -o imapsync.exe  ^
 --link libeay32_.dll ^
 --link zlib1_.dll ^
 --link ssleay32_.dll ^
 .\imapsync

echo Done building imapsync.exe 

@REM Previous options to pp
@REM Previous options to pp
@REM      --link libeay32_.dll ^
@REM      --link zlib1_.dll ^
@REM      --link ssleay32_.dll ^
@REM      -M Mail::IMAPClient ^
@REM      -M IO::Socket ^
@REM      -M IO::Socket::IP ^
@REM      -M IO::Socket::SSL ^
@REM      -M IO::Socket::INET ^
@REM      -M Digest::MD5 ^
@REM      -M Digest::HMAC_MD5 ^
@REM      -M Digest::HMAC_SHA1 ^
@REM      -M Term::ReadKey ^
@REM      -M File::Spec ^
@REM      -M Authen::NTLM ^
@REM      -M Time::Local ^
@REM      -M URI::Escape ^
@REM      -M Data::Uniqid ^
@REM      -M File::Copy::Recursive ^
@REM      -M IO::Tee ^
@REM      -M Unicode::String ^
@REM      -M JSON::WebToken ^
@REM      -M LWP::UserAgent ^
@REM      -M HTML::Entities ^
@REM      -M JSON ^

EXIT

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
 -M Crypt::OpenSSL::RSA ^
 -M JSON ^
