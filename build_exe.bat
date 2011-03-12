
REM $Id: build_exe.bat,v 1.3 2010/09/06 02:16:24 gilles Exp gilles $

echo Building imapsync.exe
cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mDigest::MD5 -mTerm::ReadKey -mIO::Socket::SSL -mFile::Spec -mDigest::HMAC_MD5 -e ''

pp -o imapsync.exe -M Term::ReadKey -M IO::Socket::SSL -M Digest::HMAC_MD5 imapsync

echo Done building imapsync.exe 
