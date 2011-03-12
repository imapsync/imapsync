

cd C:\msys\1.0\home\Admin\imapsync
perl -mMail::IMAPClient -mDigest::MD5 -mTerm::ReadKey -mIO::Socket::SSL -mFile::Spec -mDigest::HMAC_MD5 -e ''

.\imapsync.exe
.\imapsync.exe --host1 p  --user1 toto --passfile1 secret.toto  --host2 p --user2 titi --passfile2 secret.titi --noauthmd5 --delete2 --expunge2 
.\imapsync.exe --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --noauthmd5 --delete2 --expunge2 --folder INBOX 

