
REM $Id: build_exe.bat,v 1.12 2013/05/06 08:16:26 gilles Exp gilles $
REM

echo Building imapsync.exe
cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mIO::Socket -mIO::Socket::SSL ^
     -mDigest::MD5 -mDigest::HMAC_MD5 -mDigest::HMAC_SHA1 ^
     -mTerm::ReadKey  -mFile::Spec -mAuthen::NTLM ^
     -mTime::Local -mURI::Escape -mData::Uniqid^
     -e ''

pp -o imapsync.exe  --link libeay32_.dll --link libssl32_.dll ^
     -M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL ^
     -M Digest::MD5 -M Digest::HMAC_MD5 -M Digest::HMAC_SHA1 ^
     -M Term::ReadKey -M Authen::NTLM ^
     -M Time::Local -M URI::Escape -M Data::Uniqid ^
   imapsync

echo Done building imapsync.exe 
