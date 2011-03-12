
REM $Id: test.bat,v 1.6 2010/08/15 11:10:49 gilles Exp gilles $

echo Building imapsync.exe
cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mDigest::MD5 -mTerm::ReadKey -mIO::Socket::SSL -mDate::Manip -mFile::Spec -mDigest::HMAC_MD5 -e ''

REM -M Date::Manip 6.xx buggy?
pp -o imapsync.exe -M Term::ReadKey -M IO::Socket::SSL -M Digest::HMAC_MD5 imapsync

echo Done building imapsync.exe 
