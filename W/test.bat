
REM $Id: test.bat,v 1.10 2012/12/22 20:00:12 gilles Exp gilles $

cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mDigest::MD5 -mTerm::ReadKey -mIO::Socket::SSL -mDate::Manip -mFile::Spec -mDigest::HMAC_MD5 -e ''

perl ./imapsync 
perl ./imapsync --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --delete2 --expunge2 
perl ./imapsync --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --delete2 --expunge2 --folder INBOX --nofoldersizes
perl ./imapsync --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --delete2 --expunge2 --folder INBOX --nofoldersizes --usecache

