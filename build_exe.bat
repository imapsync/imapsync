
REM $Id: build_exe.bat,v 1.6 2010/10/24 23:51:48 gilles Exp gilles $

echo Building imapsync.exe
cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mDigest::MD5 -mTerm::ReadKey -mIO::Socket::SSL -mFile::Spec -mDigest::HMAC_MD5 -e ''

pp -o imapsync.exe -M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL -M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey imapsync

echo Done building imapsync.exe 
