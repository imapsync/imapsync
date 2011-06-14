
REM $Id: build_exe.bat,v 1.9 2011/05/31 08:28:29 gilles Exp gilles $

echo Building imapsync.exe
cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mIO::Socket -mIO::Socket::SSL ^
     -mDigest::MD5 -mDigest::HMAC_MD5 ^
     -mTerm::ReadKey  -mFile::Spec -mAuthen::NTLM ^
     -mTime::Local ^
     -e ''

pp -o imapsync.exe  --link libeay32_.dll --link libssl32_.dll ^
     -M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL ^
     -M Digest::MD5 -M Digest::HMAC_MD5 ^
     -M Term::ReadKey -M Authen::NTLM ^
     -M Time::Local ^
   imapsync

echo Done building imapsync.exe 
