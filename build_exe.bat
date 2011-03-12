
REM $Id: build_exe.bat,v 1.8 2010/11/09 01:22:29 gilles Exp gilles $

echo Building imapsync.exe
cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mDigest::MD5 -mTerm::ReadKey -mIO::Socket::SSL -mFile::Spec -mDigest::HMAC_MD5 -mAuthen::NTLM -e ''

pp -o imapsync.exe  --link libeay32_.dll --link libssl32_.dll -M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL -M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey -M Authen::NTLM imapsync

echo Done building imapsync.exe 
