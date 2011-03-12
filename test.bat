
REM $Id: test.bat,v 1.7 2010/10/08 01:43:35 gilles Exp gilles $

cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mDigest::MD5 -mTerm::ReadKey -mIO::Socket::SSL -mDate::Manip -mFile::Spec -mDigest::HMAC_MD5 -e ''

perl ./imapsync
perl ./imapsync --host1 l  --user1 toto --passfile1 secret.toto  --host2 l --user2 titi --passfile2 secret.titi --noauthmd5 --delete2 --expunge2 
perl ./imapsync --host1 l  --user1 tata --passfile1 secret.tata  --host2 l --user2 titi --passfile2 secret.titi --noauthmd5 --delete2 --expunge2 --folder INBOX

