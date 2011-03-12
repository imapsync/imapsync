
%REM $Id: test.bat,v 1.5 2010/07/16 23:27:13 gilles Exp gilles $

cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mDigest::MD5 -mTerm::ReadKey -mIO::Socket::SSL -mDate::Manip -mFile::Spec -mDigest::HMAC_MD5 -e ''

set TZ="GMT"
perl ./imapsync --host1 l  --user1 toto --passfile1 secret.toto  --host2 l --user2 titi --passfile2 secret.titi --noauthmd5 --delete2 --expunge2 
perl ./imapsync --host1 l  --user1 tata --passfile1 secret.tata  --host2 l --user2 titi --passfile2 secret.titi --noauthmd5 --delete2 --expunge2 --folder INBOX

% REM -M Date::Manip 6.xx buggy?
pp -o imapsync.exe -M Term::ReadKey -M IO::Socket::SSL -M Digest::HMAC_MD5 imapsync

.\imapsync.exe --host1 l  --user1 toto --passfile1 secret.toto  --host2 l --user2 titi --passfile2 secret.titi --noauthmd5 --delete2 --expunge2 

.\imapsync.exe --host1 l  --user1 tata --passfile1 secret.tata  --host2 l --user2 titi --passfile2 secret.titi --noauthmd5 --delete2 --expunge2 --folder INBOX


